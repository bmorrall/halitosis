# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in halitosis.gemspec
gemspec

unless ["", "none"].include?(rails_version = ENV.fetch("RAILS_VERSION", ""))
  gem "rails", "~> #{rails_version}.0"
end

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"

gem "standard", ">= 1.35.1"
gem "standard-performance"
gem "standard-rspec"

gem "pry"
