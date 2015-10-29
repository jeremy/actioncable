module ActionCable
  module Channel
    module PeriodicTimers
      extend ActiveSupport::Concern

      included do
        class_attribute :periodic_timers, instance_reader: false
        self.periodic_timers = []

        on_subscribe   :start_periodic_timers
        on_unsubscribe :stop_periodic_timers
      end

      module ClassMethods
        # Allow you to call a private method <tt>every</tt> so often seconds. This periodic timer can be useful
        # for sending a steady flow of updates to a client based off an object that was configured on subscription.
        # It's an alternative to using streams if the channel is able to do the work internally.
        def periodically(callback, every:)
          self.periodic_timers += [ [ callback, every: every ] ]
        end
      end

      private
        def start_periodic_timers
          @run_periodic_timers = true
          @active_periodic_timers = self.class.periodic_timers.map do |callback, options|
            schedule_periodic_timer callback, options
          end
        end

        def stop_periodic_timers
          @run_periodic_timers = false
          Concurrent.zip(*@active_periodic_timers).wait
        end

        def schedule_periodic_timer(callback, options)
          if @run_periodic_timers
            Concurrent.
              schedule(options[:every]) { run_periodic_timer callback }.
              rescue { |exception| rescue_periodic_timer_error exception }.
              then { schedule_periodic_timer callback, options }
          end
        end

        def run_periodic_timer(callback)
          if @run_periodic_timers
            connection.worker.run_periodic_timer self, callback
          end
        end

        def rescue_periodic_timer_error(exception)
          case exception
          when StandardError
            report_periodic_timer_error exception
          else
            raise exception
          end
        end

        def report_periodic_timer_error(exception)
        end
    end
  end
end
