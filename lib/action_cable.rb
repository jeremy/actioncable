require 'active_support'
require 'active_support/rails'
require 'action_cable/version'

module ActionCable
  extend ActiveSupport::Autoload

  # Singleton instance of the server
  require 'concurrent-edge'
  SERVER = Concurrent.delay { ActionCable::Server::Base.new }
  module_function def server
    SERVER.value
  end

  eager_autoload do
    autoload :Server
    autoload :Connection
    autoload :Channel
    autoload :RemoteConnections
  end
end

require 'action_cable/engine' if defined?(Rails)
