require 'ostruct'

class TestServer < ActionCable::Server::Base
  class Configuration < OpenStruct
    def initialize
      super
      self.connection_class = ActionCable::Connection::Base
      self.logger = ActiveSupport::TaggedLogging.new ActiveSupport::Logger.new(StringIO.new)
      self.log_tags = []
      self.disable_request_forgery_protection = false
    end
  end

  attr_reader :logger

  def initialize(pubsub:)
    config = Configuration.new
    @logger = config.logger
    yield config if block_given?
    super config, pubsub: pubsub
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
