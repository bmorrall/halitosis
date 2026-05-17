# frozen_string_literal: true

rails_version = ENV["RAILS_VERSION"].to_s
pagination_adapter = ENV["PAGINATION_ADAPTER"].to_s

if rails_version != "" && pagination_adapter.empty?
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
    enable_coverage :branch
    minimum_coverage line: 100
  end
end

require "bundler/setup"
require "bundler"
require "rspec"

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

  %w[kaminari will_paginate pagy].each do |adapter|
    config.filter_run_excluding adapter.to_sym => true unless pagination_adapter == adapter
  end
end

# Optional Rails setup
unless rails_version.empty?
  require "rails_helper"
  require "halitosis"
end
