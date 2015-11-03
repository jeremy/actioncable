require 'test_helper'
require 'stubs/test_connection'
require 'stubs/room'

class ActionCable::Channel::BaseTest < ActiveSupport::TestCase
  class ActionCable::Channel::Base
    def kick
      @last_action = [ :kick ]
    end

    def topic
    end
  end

  class BasicChannel < ActionCable::Channel::Base
    def chatters
      @last_action = [ :chatters ]
    end
  end

  class ChatChannel < BasicChannel
    attr_reader :room, :last_action
    on_subscribe :toggle_subscribed
    on_unsubscribe :toggle_subscribed

    def initialize(*)
      @subscribed = false
      super
    end

    def subscribed
      @room = Room.new params[:id]
      @actions = []
    end

    def unsubscribed
      @room = nil
    end

    def toggle_subscribed
      @subscribed = !@subscribed
    end

    def leave
      @last_action = [ :leave ]
    end

    def speak(data)
      @last_action = [ :speak, data ]
    end

    def topic(data)
      @last_action = [ :topic, data ]
    end

    def subscribed?
      @subscribed
    end

    def get_latest
      transmit data: 'latest'
    end

    private
      def rm_rf
        @last_action = [ :rm_rf ]
      end
  end

  setup do
    @user = User.new "lifo"
    connection = TestConnection.new(@user)
    @channel = ChatChannel.new connection, "{id: 1}", { id: 1 }
  end

  test "should not subscribe to a channel on initialize" do
    assert_nil @channel.room
  end

  test "on subscribe callbacks" do
    @channel.subscribe_to_channel
    assert @channel.subscribed?
    assert @channel.room
  end

  test "channel params" do
    assert_equal({ id: 1 }, @channel.params)
  end

  test "unsubscribing from a channel" do
    @channel.subscribe_to_channel
    assert @channel.room
    assert @channel.subscribed?

    @channel.unsubscribe_from_channel
    assert_nil @channel.room
    assert_not @channel.subscribed?
  end

  test "connection identifier delegated to connection" do
    assert_equal @channel.connection.current_user, @channel.current_user

    @channel.connection.expects(:current_user).returns(:foo)
    assert_equal :foo, @channel.current_user
  end

  test "callable action without any argument" do
    @channel.perform_action 'action' => :leave
    assert_equal [ :leave ], @channel.last_action
  end

  test "callable action with arguments" do
    data = { 'action' => :speak, 'content' => "Hello World" }

    @channel.perform_action data
    assert_equal [ :speak, data ], @channel.last_action
  end

  test "should not dispatch a private method" do
    @channel.perform_action 'action' => :rm_rf
    assert_nil @channel.last_action
  end

  test "should not dispatch a public method defined on Base" do
    @channel.perform_action 'action' => :kick
    assert_nil @channel.last_action
  end

  test "should dispatch a public method defined on Base and redefined on channel" do
    data = { 'action' => :topic, 'content' => "This is Sparta!" }

    @channel.perform_action data
    assert_equal [ :topic, data ], @channel.last_action
  end

  test "should dispatch calling a public method defined in an ancestor" do
    @channel.perform_action 'action' => :chatters
    assert_equal [ :chatters ], @channel.last_action
  end

  test "transmitting data" do
    @channel.perform_action 'action' => :get_latest

    expected = ActiveSupport::JSON.encode "identifier" => "{id: 1}", "message" => { "data" => "latest" }
    assert_equal expected, @channel.connection.last_transmission
  end
end
