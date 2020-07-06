module Forkworker
  class Worker
    include Forkworker::Logger

    def work!(worker_data, &block)
      @worker_data = worker_data
      @running = true
      update_title("spawned")
      traps

      instance_eval(&block)

      exit(0)
    end

    private

    def traps
      trap(:TERM) do
        @running = false
        update_title
      end
    end

    def update_title(status = nil)
      @last_status = status if status
      run_state = @running ? 'running' : 'shutting down'

      $PROGRAM_NAME = "Worker ##{Process.pid} | #{run_state} | #{@last_status}"
    end
  end
end
