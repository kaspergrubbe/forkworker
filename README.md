# Forkworker

A simple Ruby-gem to manage forking workloads that allows an operator to control the number of workers needed on the fly with signals.

## Installation

```bash
$ gem install forkworker
```

Or in a Gemfile:

```ruby
gem "forkworker"
```

## Usage

Have a look in the test-folder to see more elaborate examples.

Basic usage is like this:

```ruby
require 'forkworker'

NUMBER_OF_WORKER_PROCESSES = 4
fw = Forkworker::Leader.new(NUMBER_OF_WORKER_PROCESSES,
  setup_block: Proc.new {
    # Setup block will only be run once
    $count = 0
  },
  prefork_block: Proc.new {
    # If the prefork block raises Forkworker::NoMoreWork
    # no new processes will be launched.
    #
    # If no prefork block exists, or it doesn't raise Forkworker::NoMoreWork
    # then fork/work will continue endlessly
    if $count >= 20
      raise Forkworker::NoMoreWork
    end
  },
  fork_block: Proc.new {
    # Fork block will be run in the forked process
    # you can use the update_title-method to update the process title
    update_title("Count is: #{$count}")
    sleep 5
  },
  reporting_block: Proc.new {
    # Reporting block will run once in a while, you can use that for printing progress
    puts "Progress: #{$count}"
    $count += 1
  },
)
fw.start!
```

## Signals

### Increase number of workers (SIGTTIN)

```bash
$ kill -SIGTTIN leader_pid
```

### Decrease number of workers (SIGTTOU)

```bash
$ kill -SIGTTOU leader_pid
```

### Ask leader to terminate (SIGTERM)

```bash
$ kill -SIGTERM leader_pid
```

### Ask leader to quit (SIGQUIT)

```bash
$ kill -SIGQUIT leader_pid
```

## Run tests

```bash
make testsuite
```

