Gem::Specification.new do |s|
  s.name        = "forkworker"
  s.version     = "0.0.1"
  s.date        = "2020-07-03"
  s.summary     = "Manage forking workloads with ease"
  s.description = "Forkworker lets you manage forking workloads easily"
  s.authors     = ["Kasper Grubbe"]
  s.email       = "rubygems@kaspergrubbe.com"
  s.homepage    = "https://rubygems.org/gems/forkworker"
  s.license     = "MIT"
  s.files       = [
    "lib/forkworker.rb",
    "lib/forkworker/leader.rb",
    "lib/forkworker/logger.rb",
    "lib/forkworker/worker.rb",
  ]
  s.add_development_dependency "rspec", "~> 3.9.0"
  s.add_development_dependency "pry", "~> 0.13.1"
  s.add_development_dependency "pry-remote", "~> 0.1.8"
end
