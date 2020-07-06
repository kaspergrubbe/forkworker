module Forkworker
  module Logger
    def debug(logline)
      puts logline if ENV["DEBUG"] == "1"
    end
  end
end
