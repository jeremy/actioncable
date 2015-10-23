require 'concurrent-edge'
require 'active_support/callbacks'

module ActionCable
  module Server
    # Worker used by Server.send_async to do connection work in threads. Only for internal use.
    class Worker
      include ActiveSupport::Callbacks

      attr_reader :connection
      define_callbacks :work
      include ActiveRecordConnectionManagement

      def send_async(receiver, method, *args)
        Concurrent.
          future { invoke receiver, method, *args }.
          rescue { |e| receiver.handle_exception e if receiver.respond_to?(:handle_exception) }
      end

      def invoke(receiver, method, *args)
        @connection = receiver

        run_callbacks :work do
          receiver.send method, *args
        end
      end

      def run_periodic_timer(channel, callback)
        @connection = channel.connection

        run_callbacks :work do
          callback.respond_to?(:call) ? channel.instance_exec(&callback) : channel.send(callback)
        end
      end
    end
  end
end
