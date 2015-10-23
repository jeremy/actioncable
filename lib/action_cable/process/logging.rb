require 'action_cable/server'
require 'eventmachine'
require 'concurrent-edge'

EM.error_handler do |e|
  puts "Error raised inside the event loop: #{e.message}"
  puts e.backtrace.join("\n")
end

Concurrent.global_logger = ActionCable.server.logger
