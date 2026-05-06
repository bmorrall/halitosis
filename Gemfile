# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in halitosis.gemspec
gemspec

rails_version = ENV["RAILS_VERSION"].to_s
unless rails_version.empty?
  gem "rails", "~> #{rails_version}.0"
  gem "rspec-rails"
end

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"

gem "standard", ">= 1.35.1"
gem "standard-performance"

gem "pry"

gem "simplecov", require: false
