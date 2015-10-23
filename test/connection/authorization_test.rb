require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::AuthorizationTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :websocket

    def connect
      reject_unauthorized_connection
    end
  end

  test "unauthorized connection" do
    run_in_eventmachine do
      server = TestServer.new
      connection = Connection.new(server, server.mock_env)
      connection.websocket.expects(:close)
      connection.process
      connection.send :on_open
    end
  end
end
