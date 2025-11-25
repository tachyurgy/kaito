# frozen_string_literal: true

require 'simplecov'
require 'simplecov-json'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  add_filter '/examples/'

  # Generate both HTML (for local) and JSON (for Codecov) reports
  if ENV['COVERAGE']
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::JSONFormatter
    ])
  end

  # Enforce minimum coverage threshold
  minimum_coverage 85
  minimum_coverage_by_file 70

  # Track branch coverage too (if SimpleCov supports it)
  enable_coverage :branch if SimpleCov.respond_to?(:enable_coverage)
end

require 'kaito'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Improved output
  config.order = :random
  Kernel.srand config.seed
end
