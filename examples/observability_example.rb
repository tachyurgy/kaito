#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating Kaito's observability features
#
# This example shows how to use:
# - Structured logging
# - Instrumentation hooks
# - Metrics integration
#
# Run with: ruby examples/observability_example.rb

require_relative '../lib/kaito'

# Example text for demonstration
EXAMPLE_TEXT = <<~TEXT
  Ruby is a dynamic, open source programming language with a focus on simplicity
  and productivity. It has an elegant syntax that is natural to read and easy to
  write. Ruby was created by Yukihiro Matsumoto (Matz) in the mid-1990s.

  Ruby is known for its flexibility and object-oriented features. Everything in
  Ruby is an object, including primitive data types. This consistency makes the
  language intuitive and powerful.

  The Ruby community values programmer happiness and follows the principle of
  "Convention over Configuration". This philosophy has influenced many modern
  frameworks and tools.

  Ruby on Rails, often called Rails, is a popular web framework written in Ruby.
  It revolutionized web development by introducing patterns like MVC, REST, and
  Active Record. Rails follows the "Don't Repeat Yourself" (DRY) principle.

  Ruby's syntax is inspired by Perl, Smalltalk, Eiffel, Ada, and Lisp. This mix
  creates a unique language that emphasizes readability and natural expression.
  Ruby supports multiple programming paradigms including procedural, object-oriented,
  and functional programming.
TEXT

puts "=" * 80
puts "Kaito Observability Examples"
puts "=" * 80

# ==============================================================================
# Example 1: Structured Logging
# ==============================================================================
puts "\n1. STRUCTURED LOGGING"
puts "-" * 80

# Create a logger with text format
logger_text = Kaito::Logger.new($stdout, level: :info, format: :text)

# Configure Kaito to use the logger
Kaito.configure do |config|
  config.logger = logger_text
end

puts "\nSplitting text with text-format logging:"
splitter = Kaito::Splitters::Semantic.new(max_tokens: 100, overlap_tokens: 10)
chunks = splitter.split(EXAMPLE_TEXT)

puts "\nGenerated #{chunks.size} chunks"

# Example with JSON logging
puts "\n" + "-" * 80
puts "Splitting text with JSON-format logging:"

logger_json = Kaito::Logger.new($stdout, level: :info, format: :json)
Kaito.configure do |config|
  config.logger = logger_json
end

splitter = Kaito::Splitters::Character.new(max_tokens: 80)
chunks = splitter.split(EXAMPLE_TEXT)

# ==============================================================================
# Example 2: Instrumentation Hooks
# ==============================================================================
puts "\n\n2. INSTRUMENTATION HOOKS"
puts "-" * 80

# Clear previous logger to focus on instrumentation
Kaito.configure do |config|
  config.logger = nil
  config.instrumentation_enabled = true
end

# Subscribe to all instrumentation events
puts "\nSubscribing to all Kaito events:"
Kaito::Instrumentation.subscribe do |event|
  puts "Event: #{event.name}"
  puts "  Duration: #{event.duration}ms"
  puts "  Payload: #{event.payload.inspect}"
  puts
end

# Perform operations that trigger instrumentation
puts "Splitting text (instrumentation enabled):"
splitter = Kaito::Splitters::Semantic.new(max_tokens: 100)
chunks = splitter.split(EXAMPLE_TEXT)

# Subscribe to specific events only
puts "\n" + "-" * 80
puts "Subscribing to text_split events only:"

Kaito::Instrumentation.clear_subscriptions
Kaito::Instrumentation.subscribe('text_split.kaito') do |event|
  strategy = event.payload[:strategy]
  chunks_count = event.payload[:chunks_created]
  tokens = event.payload[:tokens_processed]

  puts "Split completed using #{strategy} strategy"
  puts "  Created #{chunks_count} chunks with #{tokens} total tokens"
  puts "  Took #{event.duration_seconds}s"
end

splitter = Kaito::Splitters::Recursive.new(max_tokens: 120)
chunks = splitter.split(EXAMPLE_TEXT)

# Pattern matching with regex
puts "\n" + "-" * 80
puts "Subscribing with regex pattern (all .kaito events):"

Kaito::Instrumentation.clear_subscriptions
event_counts = Hash.new(0)

Kaito::Instrumentation.subscribe(/\.kaito$/) do |event|
  event_counts[event.name] += 1
end

# Perform multiple operations
splitter1 = Kaito::Splitters::Semantic.new(max_tokens: 100)
splitter1.split(EXAMPLE_TEXT)

splitter2 = Kaito::Splitters::Character.new(max_tokens: 80)
splitter2.split(EXAMPLE_TEXT)

puts "Event counts:"
event_counts.each do |name, count|
  puts "  #{name}: #{count}"
end

# ==============================================================================
# Example 3: Metrics Integration (Simulated)
# ==============================================================================
puts "\n\n3. METRICS INTEGRATION"
puts "-" * 80

# Create a simple custom metrics client for demonstration
class DemoMetricsClient
  attr_reader :metrics_data

  def initialize
    @metrics_data = {
      increments: [],
      timings: [],
      gauges: []
    }
  end

  def increment(metric, value = 1, tags: {})
    @metrics_data[:increments] << { metric: metric, value: value, tags: tags }
    puts "  [Increment] #{metric} += #{value} #{tags_str(tags)}"
  end

  def timing(metric, value, tags: {})
    @metrics_data[:timings] << { metric: metric, value: value, tags: tags }
    puts "  [Timing] #{metric} = #{value.round(2)}ms #{tags_str(tags)}"
  end

  def gauge(metric, value, tags: {})
    @metrics_data[:gauges] << { metric: metric, value: value, tags: tags }
    puts "  [Gauge] #{metric} = #{value} #{tags_str(tags)}"
  end

  private

  def tags_str(tags)
    return "" if tags.empty?
    "[#{tags.map { |k, v| "#{k}:#{v}" }.join(', ')}]"
  end
end

# Configure Kaito with custom metrics
Kaito::Instrumentation.clear_subscriptions
Kaito.configure do |config|
  config.instrumentation_enabled = false
  config.metrics = Kaito::Metrics.new(
    backend: :custom,
    client: DemoMetricsClient.new,
    namespace: 'kaito',
    tags: { env: 'example', version: '1.0' }
  )
end

puts "\nSplitting text with metrics tracking:"
splitter = Kaito::Splitters::Semantic.new(max_tokens: 100, overlap_tokens: 10)
chunks = splitter.split(EXAMPLE_TEXT)

# Show metrics summary
puts "\n" + "-" * 80
puts "Metrics Summary:"
client = Kaito.configuration.metrics.client
puts "Total increments: #{client.metrics_data[:increments].size}"
puts "Total timings: #{client.metrics_data[:timings].size}"
puts "Total gauges: #{client.metrics_data[:gauges].size}"

# ==============================================================================
# Example 4: Combined Observability
# ==============================================================================
puts "\n\n4. COMBINED OBSERVABILITY (Logger + Instrumentation + Metrics)"
puts "-" * 80

# Set up all observability features
Kaito.configure do |config|
  # Logger with JSON format for structured logs
  config.logger = Kaito::Logger.new($stdout, level: :info, format: :json)

  # Metrics with custom client
  config.metrics = Kaito::Metrics.new(
    backend: :custom,
    client: DemoMetricsClient.new,
    namespace: 'kaito'
  )

  # Enable instrumentation
  config.instrumentation_enabled = true
end

# Subscribe to events for custom processing
Kaito::Instrumentation.subscribe('text_split.kaito') do |event|
  # You could forward to APM, send to logging service, etc.
  puts "\n[Custom Event Handler] Split event received"
  puts "  Strategy: #{event.payload[:strategy]}"
  puts "  Performance: #{event.duration}ms for #{event.payload[:chunks_created]} chunks"
end

puts "\nPerforming split with full observability:"
splitter = Kaito::Splitters::AdaptiveOverlap.new(max_tokens: 100)
chunks = splitter.split(EXAMPLE_TEXT)

puts "\n" + "=" * 80
puts "Example completed!"
puts "=" * 80

# ==============================================================================
# Example 5: Real-world StatsD/Datadog Integration (commented out)
# ==============================================================================

puts "\n\n5. REAL-WORLD INTEGRATION EXAMPLES (code only, not executed)"
puts "-" * 80

real_world_example = <<~'RUBY'
  # StatsD Integration
  # ------------------
  # Gemfile:
  #   gem 'statsd-instrument'

  require 'statsd-instrument'

  statsd_client = StatsD.new('localhost', 8125)

  Kaito.configure do |config|
    config.metrics = Kaito::Metrics.new(
      backend: :statsd,
      client: statsd_client,
      namespace: 'kaito',
      tags: { service: 'text_processor', env: ENV['RACK_ENV'] }
    )
  end

  # Datadog Integration
  # ------------------
  # Gemfile:
  #   gem 'dogstatsd-ruby'

  require 'datadog/statsd'

  datadog_client = Datadog::Statsd.new('localhost', 8125)

  Kaito.configure do |config|
    config.metrics = Kaito::Metrics.new(
      backend: :datadog,
      client: datadog_client,
      namespace: 'kaito',
      tags: { service: 'text_processor' }
    )
  end

  # Custom Metrics Backend
  # ---------------------
  # Implement your own metrics client

  class PrometheusMetrics
    def initialize
      @registry = Prometheus::Client.registry
      @counter = @registry.counter(:kaito_splits_total, 'Total splits')
      @histogram = @registry.histogram(:kaito_split_duration_seconds, 'Split duration')
    end

    def increment(metric, value = 1, tags: {})
      @counter.increment(by: value, labels: tags)
    end

    def timing(metric, value_ms, tags: {})
      @histogram.observe(value_ms / 1000.0, labels: tags)
    end

    def gauge(metric, value, tags: {})
      # Implement gauge logic
    end
  end

  Kaito.configure do |config|
    config.metrics = Kaito::Metrics.new(
      backend: :custom,
      client: PrometheusMetrics.new
    )
  end

  # Production-ready Setup
  # ---------------------
  # Combine all observability features for production

  Kaito.configure do |config|
    # Structured JSON logging to stdout (for log aggregation)
    config.logger = Kaito::Logger.new(
      $stdout,
      level: ENV['LOG_LEVEL']&.to_sym || :info,
      format: :json
    )

    # StatsD metrics for monitoring dashboards
    config.metrics = Kaito::Metrics.new(
      backend: :statsd,
      client: StatsD.new(ENV['STATSD_HOST'], ENV['STATSD_PORT']),
      namespace: 'kaito',
      tags: {
        service: 'text_processor',
        env: ENV['RACK_ENV'],
        version: Kaito::VERSION
      }
    )

    # Instrumentation for APM integration
    config.instrumentation_enabled = true
  end

  # Subscribe to events for APM tracing
  Kaito::Instrumentation.subscribe(/\.kaito$/) do |event|
    # Forward to your APM system (New Relic, Datadog APM, etc.)
    NewRelic::Agent.record_metric("Custom/Kaito/#{event.name}", event.duration)
  end
RUBY

puts real_world_example
