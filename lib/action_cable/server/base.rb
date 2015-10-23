require 'concurrent-edge'

module ActionCable
  module Server
    # A singleton ActionCable::Server instance is available via ActionCable.server. It's used by the rack process that starts the cable server, but
    # also by the user to reach the RemoteConnections instead for finding and disconnecting connections across all servers.
    #
    # Also, this is the server instance used for broadcasting. See Broadcasting for details.
    class Base
      include ActionCable::Server::Broadcasting
      include ActionCable::Server::Connections

      @@config = Concurrent.delay { ActionCable::Server::Configuration.new }
      def self.config
        @@config.value
      end

      def self.logger; config.logger; end
      delegate :logger, to: :config

      attr_reader :config

      def initialize(config = self.class.config)
        @config = config
        @redis = Concurrent.delay { connect_to_redis config.redis[:url] }
        @pubsub = Concurrent.delay { redis.pubsub }
        @channel_classes = Concurrent.delay { load_channel_classes }
        @worker = Concurrent.delay { ActionCable::Server::Worker.new }
        @remote_connections = Concurrent.delay { RemoteConnections.new(self) }
      end

      # Called by rack to setup the server.
      def call(env)
        setup_heartbeat_timer
        config.connection_class.new(self, env).process
      end

      # Disconnect all the connections identified by `identifiers` on this server or any others via RemoteConnections.
      def disconnect(identifiers)
        remote_connections.where(identifiers).disconnect
      end

      # Gateway to RemoteConnections. See that class for details.
      def remote_connections
        @remote_connections.value
      end

      # The worker that coordinates connection callback execution.
      def worker
        @worker.value
      end

      # Requires and returns an hash of all the channel class constants keyed by name.
      def channel_classes
        @channel_classes.value
      end

      # The redis pubsub adapter used for all streams/broadcasting.
      def pubsub
        @pubsub.value
      end

      # The EventMachine Redis instance used by the pubsub adapter.
      def redis
        @redis.value
      end

      # All the identifiers applied to the connection class associated with this server.
      def connection_identifiers
        config.connection_class.identifiers
      end

      private
        def load_channel_classes
          config.channel_paths.each { |channel_path| require channel_path }
          config.channel_class_names.each_with_object({}) { |name, hash| hash[name] = name.constantize }
        end

        def connect_to_redis(url)
          require 'em-hiredis'
          EM::Hiredis.connect(url).tap do |redis|
            redis.on(:reconnect_failed) do
              logger.info "[ActionCable] Redis reconnect failed."
            end
          end
        end
    end

    ActiveSupport.run_load_hooks(:action_cable, Base.config) if defined? ::Rails
  end
end
