require 'test_helper'
require 'stubs/test_server'
require 'stubs/user'

class ActionCable::Connection::IdentifierTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    attr_reader :websocket

    public :process_internal_message

    def connect
      self.current_user = User.new "lifo"
    end
  end

  test "connection identifier" do
    run_in_eventmachine do
      open_connection do |connection|
        assert_equal "User#lifo", connection.connection_identifier
      end
    end
  end

  test "should subscribe to internal channel on open and unsubscribe on close" do
    run_in_eventmachine do
      pubsub = mock('pubsub')
      pubsub.expects(:subscribe).with('action_cable/User#lifo')
      pubsub.expects(:unsubscribe_proc).with('action_cable/User#lifo', kind_of(Proc))

      open_connection pubsub: pubsub do
        # Do nothing, just want to check expectations on pubsub stub.
      end
    end
  end

  test "processing disconnect message" do
    run_in_eventmachine do
      open_connection do |connection|
        message = ActiveSupport::JSON.encode('type' => 'disconnect')
        connection.process_internal_message message
        assert_not connection.websocket.alive?
      end
    end
  end

  test "processing invalid message" do
    run_in_eventmachine do
      open_connection do |connection|
        message = ActiveSupport::JSON.encode('type' => 'unknown')
        connection.process_internal_message message
        assert connection.websocket.alive?
      end
    end
  end
end
