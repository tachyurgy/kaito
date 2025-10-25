# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc "Run tests"
task test: :spec

desc "Run tests with coverage"
task :coverage do
  ENV["COVERAGE"] = "true"
  Rake::Task["spec"].invoke
end

desc "Generate documentation"
task :doc do
  sh "yard doc"
end

task default: %i[spec rubocop]
