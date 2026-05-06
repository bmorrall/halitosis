# frozen_string_literal: true

if ENV["RAILS_VERSION"].to_s != ""
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
    enable_coverage :branch
    minimum_coverage line: 100
  end
end

rails_version = ENV["RAILS_VERSION"].to_s

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Enable the focus tag
  config.filter_run_when_matching :focus

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  if rails_version.empty?
    config.filter_run_excluding rails: true
    require "halitosis"
  end
end

# Optional Rails setup
unless rails_version.empty?
  require "rails_helper"
  require "halitosis"
end
