require 'ostruct'

class TestServer < ActionCable::Server::Base
  class Configuration < OpenStruct
    def initialize
      super
      self.connection_class = ActionCable::Connection::Base
      self.logger = Concurrent.global_logger
      self.log_tags = []
      self.disable_request_forgery_protection = false
    end
  end

  attr_reader :logger

  def initialize
    config = Configuration.new
    @logger = Logger.new($stderr)
    super config
  end

  def mock_env(env = {})
    default_env = {
      'HTTP_METHOD' => 'GET',
      'HTTP_CONNECTION' => 'upgrade',
      'HTTP_UPGRADE' => 'websocket',
      'HTTP_ORIGIN' => 'http://rubyonrails.com'
    }

    Rack::MockRequest.env_for '/test', default_env.merge(env)
  end
end
