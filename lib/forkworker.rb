require "forkworker/logger"
require "forkworker/leader"
require "forkworker/worker"

module Forkworker
  class NoMoreWork < StandardError; end
end
