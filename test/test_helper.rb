require "rubygems"
require "bundler"

gem 'minitest'
require "minitest/autorun"

Bundler.setup
Bundler.require :default, :test

require 'puma'
require 'mocha/mini_test'
require 'rack/mock'
require 'byebug'

require 'action_cable'
ActiveSupport.test_order = :sorted

# Require all the stubs and models
Dir[File.dirname(__FILE__) + '/stubs/*.rb'].each {|file| require file }

require 'concurrent-edge'
Concurrent.use_stdlib_logger Logger::DEBUG

require 'faye/websocket'
class << Faye::WebSocket
  remove_method :ensure_reactor_running

  # We don't want Faye to start the EM reactor in tests because it makes testing much harder.
  # We want to be able to start and stop EM loop in tests to make things simpler.
  def ensure_reactor_running
    # no-op
  end
end

class ActionCable::TestCase < ActiveSupport::TestCase
  private
    def run_in_eventmachine
      result = nil

      EM.run do
        result = yield

        EM.run_deferred_callbacks
        EM.stop
      end

      result
    end

    def open_connection(server: nil, pubsub: stub_everything('pubsub'), klass: self.class::Connection, heartbeat_interval: 1, &block)
      server ||= TestServer.new(pubsub: pubsub)
      @connection = klass.new(server, server.mock_env, heartbeat_interval: heartbeat_interval)
      @connection.process

      @connection.send :on_open
      EM.run_deferred_callbacks
      assert @connection.opened_event.wait(0.1)

      yield @connection
    ensure
      if @connection.websocket.alive?
        @connection.websocket.close

        # TODO: why isn't websocket close firing this?
        @connection.send :on_close
        EM.run_deferred_callbacks

        assert @connection.closed_event.wait(0.1)
      end
    end
end
