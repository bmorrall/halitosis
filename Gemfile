# frozen_string_literal: true

source "https://rubygems.org"

if File.exist?(".env")
  File.foreach(".env") do |line|
    next if line.strip.start_with?("#") || line.strip.empty?

    key, value = line.strip.split("=", 2)
    ENV[key] ||= value
  end
end

# Specify your gem's dependencies in halitosis.gemspec
gemspec

rails_version = ENV["RAILS_VERSION"].to_s
unless rails_version.empty?
  gem "rails", "~> #{rails_version}.0"
  gem "rspec-rails"
  gem "sqlite3", "~> 2.0"
end

unless ENV["PAGINATION_ADAPTER"].to_s.empty?
  case ENV["PAGINATION_ADAPTER"]
  when "kaminari"
    gem "kaminari"
  when "will_paginate"
    gem "will_paginate"
  when "pagy"
    gem "pagy"
  end
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
