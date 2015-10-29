require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::StringIdentifierTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :current_token

    def connect
      self.current_token = "random-string"
    end
  end

  test "connection identifier" do
    run_in_eventmachine do
      open_connection do |connection|
        assert_equal "random-string", connection.connection_identifier
      end
    end
  end
end
