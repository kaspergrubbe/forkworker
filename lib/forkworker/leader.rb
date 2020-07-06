module Forkworker
  class Leader
    include Forkworker::Logger

    def initialize(worker_num, pidfile: nil, setup_block: nil, prefork_block: nil, fork_block: nil, reporting_block: nil)
      @wanted_number_of_workers = worker_num
      @running = true
      @worker_pids = []
      @signals_received = []
      @pidfile = pidfile

      @setup_block = setup_block
      @prefork_block = prefork_block
      @fork_block = fork_block
      @reporting_block = reporting_block

      write_pid if @pidfile
    end

    def start!
      traps
      update_leader_title
      @setup_block.call if @setup_block
      spawn_missing_workers

      gameloop = 1

      until @worker_pids.dup.length == 0 && @running == false
        sleep 0.25

        # Handle actions
        while(signal = @signals_received.shift)
          case signal
          when 'CHLD'
            @worker_pids.dup.each do |wpid|
              begin
                wpid, _status = Process.waitpid(wpid, Process::WNOHANG)
                @worker_pids.delete(wpid)
              rescue Errno::ECHILD
              end
            end
          when 'TTIN'
            debug "-- handled #{signal}: wanted number of workers are now: #{@wanted_number_of_workers}"

            @wanted_number_of_workers += 1
          when 'TTOU'
            unless @wanted_number_of_workers == 0
              @wanted_number_of_workers -= 1
            end

            debug "-- handled #{signal}: wanted number of workers are now: #{@wanted_number_of_workers}"
          when 'TERM'
            debug "-- handled #{signal}"

            @running = false
            shutdown_each_worker(:TERM)
          when 'QUIT'
            debug "-- handled #{signal}"

            @running = false
            shutdown_each_worker(:QUIT)
          end
        end

        # Spawn missing workers if we are not getting shut down
        if @running
          spawn_missing_workers
        end

        if gameloop % 20 == 0 && @reporting_block
          @reporting_block.call
        end

        update_leader_title

        gameloop += 1
      end
    end

   private

    def spawn_missing_workers
      begin
        while (@worker_pids.length + 1) <= @wanted_number_of_workers
          worker_data = if @prefork_block
            @prefork_block.call
          else
            nil
          end

          if(pid = fork)
            @worker_pids << pid
            update_leader_title
          else
            Worker.new.work!(worker_data, &@fork_block)
          end
        end
      rescue Forkworker::NoMoreWork
        debug "-- No more work, so we're just finishing up running processes"
        @running = false
      end
    end

    def traps
      # By trapping the :CHLD signal our process will be notified by the kernel when one of its children exits.
      trap(:CHLD) do
        @signals_received << 'CHLD'
      end

      trap(:TERM) do
        @signals_received << 'TERM'
      end

      trap(:TTIN) do
        @signals_received << 'TTIN'
      end

      trap(:TTOU) do
        @signals_received << 'TTOU'
      end

      [:QUIT, :INT].each do |signal|
        trap(signal) do
          @signals_received << 'QUIT'
        end
      end
    end

    def update_leader_title
      run_state = @running ? 'running' : 'shutting down'
      $PROGRAM_NAME = "Leader ##{Process.pid} | #{run_state} | Workers=#{@worker_pids.length}/#{@wanted_number_of_workers}"
    end

    def shutdown_worker(signal, wpid)
      begin
        Process.kill(signal, wpid)
      rescue Errno::ESRCH
      end
    end

    def shutdown_each_worker(signal)
      @worker_pids.dup.each { |wpid| shutdown_worker(signal, wpid) }
    end

    def write_pid
      if File.exist?(@pidfile) && (pid = File.read(@pidfile))
        begin
          Process.getpgid(pid.to_i) # throws Errno::ESRCH if process with pid exists
          debug "Program is already running on pid #{pid} specified in #{@pidfile}"
          exit 1
        rescue Errno::ESRCH
          false
        end
      end

      File.open(@pidfile, 'w') do |f|
        f.write Process.pid
      end
    end

  end
end
