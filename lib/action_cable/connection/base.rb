require 'action_dispatch'

module ActionCable
  module Connection
    # For every WebSocket the cable server is accepting, a Connection object will be instantiated. This instance becomes the parent
    # of all the channel subscriptions that are created from there on. Incoming messages are then routed to these channel subscriptions
    # based on an identifier sent by the cable consumer. The Connection itself does not deal with any specific application logic beyond
    # authentication and authorization.
    #
    # Here's a basic example:
    #
    #   module ApplicationCable
    #     class Connection < ActionCable::Connection::Base
    #       identified_by :current_user
    #
    #       def connect
    #         self.current_user = find_verified_user
    #         logger.add_tags current_user.name
    #       end
    #
    #       def disconnect
    #         # Any cleanup work needed when the cable connection is cut.
    #       end
    #
    #       protected
    #         def find_verified_user
    #           if current_user = User.find_by_identity cookies.signed[:identity_id]
    #             current_user
    #           else
    #             reject_unauthorized_connection
    #           end
    #         end
    #     end
    #   end
    #
    # First, we declare that this connection can be identified by its current_user. This allows us later to be able to find all connections
    # established for that current_user (and potentially disconnect them if the user was removed from an account). You can declare as many
    # identification indexes as you like. Declaring an identification means that a attr_accessor is automatically set for that key.
    #
    # Second, we rely on the fact that the WebSocket connection is established with the cookies from the domain being sent along. This makes
    # it easy to use signed cookies that were set when logging in via a web interface to authorize the WebSocket connection.
    #
    # Finally, we add a tag to the connection-specific logger with name of the current user to easily distinguish their messages in the log.
    #
    # Pretty simple, eh?
    class Base
      include Identification
      include InternalChannel
      include Authorization

      attr_reader :server
      delegate :worker, :pubsub, to: :server

      # The request that initiated the WebSocket connection is available here. This gives access to the environment, cookies, etc.
      attr_reader :request

      attr_reader :logger

      attr_reader :websocket
      attr_reader :subscriptions

      # Events that are completed when the connection is finished opening and
      # finished closing. Used to block message handling until the connection
      # is completely opened and to act as a latch for connection testing.
      attr_reader :opened_event, :closed_event

      def initialize(server, env, heartbeat_interval: 3)
        @server = server
        @logger = new_tagged_logger(server.logger, server.config.log_tags)

        @allowed_request_origins = Array(server.config.allowed_request_origins) unless server.config.disable_request_forgery_protection

        environment = Rails.application.env_config.merge(env) if defined?(Rails.application) && Rails.application
        @request = ActionDispatch::Request.new(environment || env)

        @websocket = ActionCable::Connection::WebSocket.new(@request.env)
        @subscriptions = ActionCable::Connection::Subscriptions.new(self)

        @heartbeat_interval = heartbeat_interval
        @heartbeating = Concurrent::AtomicBoolean.new(false)

        @opened_event = Concurrent.event
        @closed_event = Concurrent.event

        @started_at = Time.now
      end

      # Called by the server when a new WebSocket connection is established. This configures the callbacks intended for overwriting by the user.
      # This method should not be called directly. Rely on the #connect (and #disconnect) callback instead.
      def process
        if websocket.possible? && allow_request_origin?
          websocket.on(:open)    { |event| send_async :on_open   }
          websocket.on(:message) { |event| on_message event.data }
          websocket.on(:close)   { |event| send_async :on_close  }

          respond_to_successful_request
        else
          respond_to_invalid_request
        end
      end

      # Data received over the cable is handled by this method. It's expected that everything inbound is JSON encoded.
      # The data is routed to the proper channel that the connection has subscribed to.
      def receive(data_in_json)
        if websocket.alive?
          subscriptions.execute_command ActiveSupport::JSON.decode(data_in_json)
        else
          logger.error "Received data without a live WebSocket (#{data_in_json.inspect})"
        end
      end

      # Send raw data straight back down the WebSocket. This is not intended to be called directly. Use the #transmit available on the
      # Channel instead, as that'll automatically address the correct subscriber and wrap the message in JSON.
      def transmit(data)
        websocket.transmit data
      end

      # Close the WebSocket connection.
      def close
        websocket.close
      end

      # Invoke a method on the connection asynchronously through the pool of thread workers.
      def send_async(method, *arguments)
        worker.send_async(self, method, *arguments)
      end

      # Return a basic hash of statistics for the connection keyed with `identifier`, `started_at`, and `subscriptions`.
      # This can be returned by a health check against the connection.
      def statistics
        {
          identifier: connection_identifier,
          started_at: @started_at,
          subscriptions: subscriptions.identifiers,
          request_id: @request.env['action_dispatch.request_id']
        }
      end

      def beat
        transmit ActiveSupport::JSON.encode(identifier: '_ping', message: Time.now.to_i)
      end


      protected
        # The cookies of the request that initiated the WebSocket connection. Useful for performing authorization checks.
        def cookies
          request.cookie_jar
        end


      private
        def connect
          # Implement in subclasses. Provide the method here for super().
        end

        def disconnect
          # Implement in subclasses. Provide the method here for super().
        end

        def on_open
          raise 'Already opened' if @opened_event.completed?
          logger.info started_request_message

          begin
            connect
          rescue ActionCable::Connection::Authorization::UnauthorizedError
            EM.next_tick { close }
          else
            subscribe_to_internal_channel
            start_heartbeat @heartbeat_interval
            @opened_event.complete
          end
        end

        def start_heartbeat(interval)
          if @heartbeating.make_true
            schedule_heartbeat interval
          end
        end

        def stop_heartbeat
          @heartbeating.make_false
        end

        def schedule_heartbeat(interval)
          Concurrent.
            schedule(interval) { beat if @heartbeating.true? }.
            then { schedule_heartbeat interval if @heartbeating.true? }
        end

        def on_message(message)
          Concurrent.
            future(:io) { @opened_event.wait }.
            then { receive message }.
            rescue { |exception| logger.error "Error handling #{message.inspect}: #{exception}" }
        end

        def on_close
          @opened_event.wait
          raise 'Already closed' if @closed_event.completed?

          stop_heartbeat
          subscriptions.unsubscribe_from_all
          unsubscribe_from_internal_channel

          disconnect

          logger.info finished_request_message
          @closed_event.complete
        end


        def allow_request_origin?
          if @allowed_request_origins.nil? || @allowed_request_origins.include?(@request.env['HTTP_ORIGIN'])
            true
          else
            logger.error("Request origin not allowed: #{@request.env['HTTP_ORIGIN']}")
            false
          end
        end

        def respond_to_successful_request
          websocket.rack_response
        end

        def respond_to_invalid_request
          logger.info finished_request_message
          [ 404, { 'Content-Type' => 'text/plain' }, [ 'Page not found' ] ]
        end


        # Tags are declared in the server but computed in the connection. This allows us per-connection tailored tags.
        def new_tagged_logger(logger, log_tags)
          TaggedLoggerProxy.new logger, tags: log_tags.map { |tag|
            tag.respond_to?(:call) ? tag.call(request) : tag.to_s.camelize }
        end

        def started_request_message
          'Started %s "%s"%s for %s at %s' % [
            request.request_method,
            request.filtered_path,
            websocket.possible? ? ' [WebSocket]' : '',
            request.ip,
            Time.now.to_s ]
        end

        def finished_request_message
          'Finished "%s"%s for %s at %s' % [
            request.filtered_path,
            websocket.possible? ? ' [WebSocket]' : '',
            request.ip,
            Time.now.to_s ]
        end
    end
  end
end
