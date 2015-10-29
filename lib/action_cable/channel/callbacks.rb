module ActionCable
  module Channel
    module Callbacks
      extend ActiveSupport::Concern

      included do
        class_attribute :on_subscribe_callbacks, :on_unsubscribe_callbacks, instance_reader: false
        cattr_accessor(:subscribe_callbacks_lock) { Concurrent::Synchronization::Lock.new }

        self.on_subscribe_callbacks = []
        self.on_unsubscribe_callbacks = []
      end

      module ClassMethods
        # Name methods that should be called when the channel is subscribed to.
        # (These methods should be private, so they're not callable by the user).
        def on_subscribe(*methods)
          subscribe_callbacks_lock.synchronize do
            self.on_subscribe_callbacks += methods
          end
        end

        # Name methods that should be called when the channel is unsubscribed from.
        # (These methods should be private, so they're not callable by the user).
        def on_unsubscribe(*methods)
          subscribe_callbacks_lock.synchronize do
            self.on_unsubscribe_callbacks += methods
          end
        end
      end
    end
  end
end
