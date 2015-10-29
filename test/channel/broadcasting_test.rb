require 'test_helper'
require 'stubs/test_connection'
require 'stubs/room'

class ActionCable::Channel::BroadcastingTest < ActiveSupport::TestCase
  class ChatChannel < ActionCable::Channel::Base
  end
end

class ActionCable::Channel::BroadcastToTest < ActionCable::Channel::BroadcastingTest
  test 'delegates broadcasts to server' do
    assert_broadcasted 'Hello World', to: 'action_cable:channel:broadcasting_test:chat:Room#1-Campfire' do
      ChatChannel.broadcast_to Room.new(1), 'Hello World'
    end
  end

  private
    def assert_broadcasted(message, to:)
      mock_server = mock()
      mock_server.expects(:broadcast).with(to, message)
      ActionCable.stubs(:server).returns(mock_server)
      yield
    end
end

class ActionCable::Channel::BroadcastingForTest < ActionCable::Channel::BroadcastingTest
  test 'object' do
    assert_broadcasts_for "Room#1-Campfire", Room.new(1)
  end

  test 'array' do
    assert_broadcasts_for "Room#1-Campfire:Room#2-Campfire", [ Room.new(1), Room.new(2) ]
  end

  test 'string' do
    assert_broadcasts_for 'hello', 'hello'
  end

  private
    def assert_broadcasts_for(expected, broadcasting_object)
      assert_equal expected, ChatChannel.broadcasting_for(broadcasting_object)
    end
end
