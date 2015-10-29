require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::BaseTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :websocket, :subscriptions
  end

  setup do
    @server = TestServer.new(pubsub: mock())
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  test "making a connection with invalid headers" do
    run_in_eventmachine do
      response = ActionCable::Connection::Base.new(@server, Rack::MockRequest.env_for("/test")).process
      assert_equal 404, response[0]
    end
  end

  test "websocket connection" do
    run_in_eventmachine do
      open_connection do |connection|
        assert connection.websocket.possible?
        assert connection.websocket.alive?
      end
    end
  end

  test "rack response" do
    run_in_eventmachine do
      response = Connection.new(@server, @server.mock_env).process
      assert_equal [ -1, {}, [] ], response
    end
  end

  test "schedules heartbeat on connection open" do
    run_in_eventmachine do
      open_connection heartbeat_interval: 0.01 do |connection|
        connection.websocket.expects(:transmit).with(regexp_matches(/\_ping/)).at_least_once
        sleep 0.02
      end
    end
  end

  test "unsubscribes channels on connection close" do
    run_in_eventmachine do
      open_connection do |connection|
        connection.subscriptions.expects(:unsubscribe_from_all)
      end
    end
  end

  test "connection statistics" do
    statistics =
      run_in_eventmachine do
        open_connection &:statistics
      end

    assert statistics[:identifier].blank?
    assert_kind_of Time, statistics[:started_at]
    assert_equal [], statistics[:subscriptions]
  end

  test "explicitly closing a connection" do
    run_in_eventmachine do
      open_connection do |connection|
        connection.websocket.expects(:close)
      end
    end
  end

  private
    def open_connection(**connection_options, &block)
      super server: @server, klass: Connection, **connection_options, &block
    end
end
