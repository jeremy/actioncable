require 'test_helper'
require 'stubs/test_connection'
require 'stubs/room'

class ActionCable::Channel::PeriodicTimersTest < ActiveSupport::TestCase
  class ChatChannel < ActionCable::Channel::Base
    periodically -> { ping }, every: 0.02
    periodically :send_updates, every: 0.04

    attr_reader :pinged, :pings

    def initialize(*)
      @pings = 0
      @pinged = Concurrent.future
      super
    end

    private
      def ping
        @pings += 1
        @pinged.success @pings if @pinged.pending?
      end

      def send_updates
      end
  end

  setup do
    # TODO: Make it easy to instantiate a server instance. Lots of coupling,
    # expectation to only run within a booting Rails app.
    logger = Logger.new($stderr)
    @server = ActionCable::Server::Base.new stub \
      connection_class: ActionCable::Connection::Base,
      logger: Concurrent.global_logger,
      log_tags: []

    env = Rack::MockRequest.env_for "/test", 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket'
    @connection = ActionCable::Connection::Base.new(@server, env)
  end

  # FIXME: This doesn't test much and it implies that our internal
  # bookkeeping is public API. Test periodic timer behavior instead.
  test "periodic timers definition" do
    timers = ChatChannel.periodic_timers

    assert_equal 2, timers.size

    first_timer = timers[0]
    assert_kind_of Proc, first_timer[0]
    assert_equal 0.02, first_timer[1][:every]

    second_timer = timers[1]
    assert_equal :send_updates, second_timer[0]
    assert_equal 0.04, second_timer[1][:every]
  end

  test "timer start and stop" do
    channel = ChatChannel.new @connection, "{id: 1}", { id: 1 }
    assert_equal 0, channel.pings

    t0 = Time.now
    channel.subscribe_to_channel

    # Wait on the first ping.
    channel.pinged.value!
    assert_in_delta 0.02, Time.now - t0, 0.015
    assert_equal 1, channel.pings

    # Unsubscribing gracefully signals periodic tasks to stop the next time
    # it's fired, so we'll wait until send_updates is called. Ping will stop
    # the next time it's called, so we'll still expect just a single ping.
    channel.unsubscribe_from_channel
    assert_in_delta 0.04, Time.now - t0, 0.015
    assert_equal 1, channel.pings
  end
end
