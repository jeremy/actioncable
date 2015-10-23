require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::CrossSiteForgeryTest < ActionCable::TestCase
  HOST = 'rubyonrails.com'

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  teardown do
    @server.config.disable_request_forgery_protection = false
    @server.config.allowed_request_origins = []
  end

  test "disable forgery protection" do
    @server.config.disable_request_forgery_protection = true
    assert_origin_allowed 'http://rubyonrails.com'
    assert_origin_allowed 'http://hax.com'
  end

  test "explicitly specified a single allowed origin" do
    @server.config.allowed_request_origins = 'http://hax.com'
    assert_origin_not_allowed 'http://rubyonrails.com'
    assert_origin_allowed 'http://hax.com'
  end

  test "explicitly specified multiple allowed origins" do
    @server.config.allowed_request_origins = %w( http://rubyonrails.com http://www.rubyonrails.com )
    assert_origin_allowed 'http://rubyonrails.com'
    assert_origin_allowed 'http://www.rubyonrails.com'
    assert_origin_not_allowed 'http://hax.com'
  end

  private
    def assert_origin_allowed(origin)
      response = connect_with_origin origin
      assert_equal -1, response[0]
    end

    def assert_origin_not_allowed(origin)
      response = connect_with_origin origin
      assert_equal 404, response[0]
    end

    def connect_with_origin(origin)
      response = nil

      run_in_eventmachine do
        response = ActionCable::Connection::Base.new(@server, @server.mock_env('HTTP_ORIGIN' => origin)).process
      end

      response
    end
end
