require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::CrossSiteForgeryTest < ActionCable::TestCase
  test "disable forgery protection" do
    server = build_server disabled: true

    assert_allowed server, origin: 'http://rubyonrails.com'
    assert_allowed server, origin: 'http://hax.com'
  end

  test "explicitly specified a single allowed origin" do
    server = build_server origins: 'http://hax.com'

    assert_allowed server, origin: 'http://hax.com'
    assert_not_allowed server, origin: 'http://rubyonrails.com'
  end

  test "explicitly specified multiple allowed origins" do
    server = build_server origins: %w[ http://rubyonrails.com http://www.rubyonrails.com ]

    assert_allowed server, origin: 'http://rubyonrails.com'
    assert_allowed server, origin: 'http://www.rubyonrails.com'
    assert_not_allowed server, origin: 'http://hax.com'
  end

  private
    def build_server(disabled: false, origins: [])
      TestServer.new(pubsub: mock()) do |config|
        config.disable_request_forgery_protection = disabled
        config.allowed_request_origins = origins
      end
    end

    def assert_allowed(server, origin:)
      response = connect_to server, origin
      assert_equal -1, response[0]
    end

    def assert_not_allowed(server, origin:)
      response = connect_to server, origin
      assert_equal 404, response[0]
    end

    def connect_to(server, origin)
      run_in_eventmachine do
        ActionCable::Connection::Base.new(server, server.mock_env('HTTP_ORIGIN' => origin)).process
      end
    end
end
