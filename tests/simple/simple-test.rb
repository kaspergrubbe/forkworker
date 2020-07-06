require 'fileutils'

# INSTALL DEPENDENCIES
# --------------------------------------------------------------------------------
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'pry'
  gem 'pry-remote'

  gem "forkworker", path: "."
end

# SETUP BLOCKS
# --------------------------------------------------------------------------------
setup = Proc.new {
  @items = [].tap { |it|
    100.times do |i|
      it << i
    end
  }.to_enum
}

prefork = Proc.new {
  forked_items = [].tap do |it|
    begin
      7.times do
        it << @items.next
      end
    rescue StopIteration
    end
  end

  if forked_items.size == 0
    raise Forkworker::NoMoreWork.new
  end

  @processed ||= 0
  @processed += forked_items.size

  forked_items
}

work = Proc.new {
  require 'fileutils'
  FileUtils.mkdir_p('tests/simple/simple-test-workloads')

  File.open("tests/simple/simple-test-workloads/#{Process.pid}.log", 'w+') do |f|
    @worker_data.each do |wd|
      f.puts(wd)
      update_title(wd)
      sleep 1
    end
  end
}

progress = Proc.new {
  puts("Work done: #{@processed}/#{@items.to_a.size}")
}

if File.directory?("tests/simple/simple-test-workloads")
  FileUtils.remove_dir("tests/simple/simple-test-workloads")
end

# RUN THE JOB
# --------------------------------------------------------------------------------
fw = Forkworker::Leader.new(4,
  setup_block: setup,
  prefork_block: prefork,
  fork_block: work,
  reporting_block: progress,
)
fw.start!

# TEST
# --------------------------------------------------------------------------------
logfile_numbers = [].tap do |it|
  Dir["tests/simple/simple-test-workloads/*.log"].each do |logfile|
    it << File.open(logfile).read.lines.map(&:strip).map(&:to_i)
  end
end.flatten

expected_logfile_numbers = [].tap do |it|
  100.times do |i|
    it << i
  end
end

if expected_logfile_numbers.size != logfile_numbers.size
  raise "Expected logfile_numbers to have #{expected_logfile_numbers.size} entries, but it had #{logfile_numbers.size}"
end

if expected_logfile_numbers != logfile_numbers.sort
  puts "Expected: #{expected_logfile_numbers.join(", ")}"
  puts "Actual:   #{logfile_numbers.sort.join(", ")}"
  raise "Logfile numbers does not match expected numbers"
end

puts
puts "All tests passed!"

# CLEANUP
# --------------------------------------------------------------------------------
if File.directory?("tests/simple/simple-test-workloads")
  FileUtils.remove_dir("tests/simple/simple-test-workloads")
end
