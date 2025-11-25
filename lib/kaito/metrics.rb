# frozen_string_literal: true

module Kaito
  # Optional metrics integration for Kaito
  #
  # Provides integration with popular metrics backends like StatsD and Datadog.
  # This is opt-in and requires the appropriate gems to be installed.
  #
  # @example StatsD integration
  #   require 'statsd-instrument'
  #
  #   Kaito.configure do |config|
  #     config.metrics = Kaito::Metrics.new(
  #       backend: :statsd,
  #       client: StatsD.new('localhost', 8125)
  #     )
  #   end
  #
  # @example Datadog integration
  #   require 'datadog/statsd'
  #
  #   Kaito.configure do |config|
  #     config.metrics = Kaito::Metrics.new(
  #       backend: :datadog,
  #       client: Datadog::Statsd.new('localhost', 8125)
  #     )
  #   end
  #
  # @example Custom backend
  #   class MyMetrics
  #     def increment(metric, tags: {})
  #       # custom implementation
  #     end
  #
  #     def timing(metric, value, tags: {})
  #       # custom implementation
  #     end
  #   end
  #
  #   Kaito.configure do |config|
  #     config.metrics = Kaito::Metrics.new(
  #       backend: :custom,
  #       client: MyMetrics.new
  #     )
  #   end
  class Metrics
    attr_reader :backend, :client, :namespace, :enabled

    # Supported metrics backends
    BACKENDS = [:statsd, :datadog, :custom, :null].freeze

    # Initialize metrics integration
    #
    # @param backend [Symbol] metrics backend (:statsd, :datadog, :custom, :null)
    # @param client [Object] metrics client instance
    # @param namespace [String] metric namespace prefix (default: 'kaito')
    # @param enabled [Boolean] whether metrics are enabled
    # @param tags [Hash] default tags to add to all metrics
    def initialize(backend: :null, client: nil, namespace: 'kaito', enabled: true, tags: {})
      @backend = backend
      @client = client
      @namespace = namespace
      @enabled = enabled
      @default_tags = tags

      validate_backend!
      setup_backend_adapter
    end

    # Track text splitting operation
    #
    # @param strategy [Symbol] splitting strategy used
    # @param duration [Float] operation duration in seconds
    # @param chunks [Integer] number of chunks created
    # @param tokens [Integer] total tokens processed
    # @param tags [Hash] additional tags
    def track_split(strategy:, duration:, chunks:, tokens: nil, **tags)
      return unless enabled

      metric_tags = build_tags(strategy: strategy, **tags)

      timing('split.duration', duration * 1000, tags: metric_tags)
      increment('split.count', tags: metric_tags)
      gauge('split.chunks', chunks, tags: metric_tags)
      gauge('split.tokens', tokens, tags: metric_tags) if tokens
    end

    # Track tokenization operation
    #
    # @param tokenizer [Symbol] tokenizer used
    # @param duration [Float] operation duration in seconds
    # @param tokens [Integer] number of tokens
    # @param tags [Hash] additional tags
    def track_tokenization(tokenizer:, duration:, tokens:, **tags)
      return unless enabled

      metric_tags = build_tags(tokenizer: tokenizer, **tags)

      timing('tokenization.duration', duration * 1000, tags: metric_tags)
      increment('tokenization.count', tags: metric_tags)
      gauge('tokenization.tokens', tokens, tags: metric_tags)
    end

    # Track file streaming operation
    #
    # @param strategy [Symbol] splitting strategy
    # @param duration [Float] operation duration in seconds
    # @param chunks [Integer] number of chunks streamed
    # @param file_size [Integer] file size in bytes
    # @param tags [Hash] additional tags
    def track_streaming(strategy:, duration:, chunks:, file_size: nil, **tags)
      return unless enabled

      metric_tags = build_tags(strategy: strategy, **tags)

      timing('streaming.duration', duration * 1000, tags: metric_tags)
      increment('streaming.count', tags: metric_tags)
      gauge('streaming.chunks', chunks, tags: metric_tags)
      gauge('streaming.file_size', file_size, tags: metric_tags) if file_size
    end

    # Track an error
    #
    # @param operation [String] operation that failed
    # @param error_type [String] type of error
    # @param tags [Hash] additional tags
    def track_error(operation:, error_type: nil, **tags)
      return unless enabled

      metric_tags = build_tags(operation: operation, error_type: error_type, **tags).compact

      increment('error.count', tags: metric_tags)
    end

    # Increment a counter
    #
    # @param metric [String] metric name
    # @param value [Integer] value to increment by
    # @param tags [Hash] metric tags
    def increment(metric, value = 1, tags: {})
      return unless enabled && client

      full_metric = namespaced_metric(metric)
      merged_tags = build_tags(**tags)
      adapter.increment(full_metric, value, tags: merged_tags)
    end

    # Record a timing in milliseconds
    #
    # @param metric [String] metric name
    # @param value [Float] timing value in milliseconds
    # @param tags [Hash] metric tags
    def timing(metric, value, tags: {})
      return unless enabled && client

      full_metric = namespaced_metric(metric)
      merged_tags = build_tags(**tags)
      adapter.timing(full_metric, value, tags: merged_tags)
    end

    # Set a gauge value
    #
    # @param metric [String] metric name
    # @param value [Numeric] gauge value
    # @param tags [Hash] metric tags
    def gauge(metric, value, tags: {})
      return unless enabled && client && !value.nil?

      full_metric = namespaced_metric(metric)
      merged_tags = build_tags(**tags)
      adapter.gauge(full_metric, value, tags: merged_tags)
    end

    # Measure execution time of a block
    #
    # @param metric [String] metric name
    # @param tags [Hash] metric tags
    # @yield block to measure
    # @return result of the block
    def measure(metric, tags: {})
      return yield unless enabled && client

      start_time = Time.now
      result = yield
      duration = (Time.now - start_time) * 1000 # Convert to milliseconds

      timing(metric, duration, tags: tags)
      result
    end

    # Enable metrics
    def enable!
      @enabled = true
    end

    # Disable metrics
    def disable!
      @enabled = false
    end

    private

    attr_reader :adapter, :default_tags

    def validate_backend!
      return if BACKENDS.include?(backend)

      raise ArgumentError, "Invalid backend: #{backend}. Supported: #{BACKENDS.join(', ')}"
    end

    def setup_backend_adapter
      @adapter = case backend
                when :statsd
                  StatsDAdapter.new(client)
                when :datadog
                  DatadogAdapter.new(client)
                when :custom
                  CustomAdapter.new(client)
                when :null
                  NullAdapter.new
                else
                  raise ArgumentError, "Unknown backend: #{backend}"
                end
    end

    def namespaced_metric(metric)
      namespace ? "#{namespace}.#{metric}" : metric
    end

    def build_tags(**tags)
      default_tags.merge(tags)
    end

    # Adapter for StatsD client
    class StatsDAdapter
      def initialize(client)
        @client = client
      end

      # Increment a counter metric
      # @param metric [String] metric name
      # @param value [Integer] value to increment by
      # @param tags [Hash] metric tags
      def increment(metric, value, tags: {})
        if @client.respond_to?(:increment)
          @client.increment(metric, value, tags: format_tags(tags))
        end
      end

      # Record a timing metric
      # @param metric [String] metric name
      # @param value [Float] timing value in milliseconds
      # @param tags [Hash] metric tags
      def timing(metric, value, tags: {})
        if @client.respond_to?(:timing)
          @client.timing(metric, value, tags: format_tags(tags))
        end
      end

      # Set a gauge metric
      # @param metric [String] metric name
      # @param value [Numeric] gauge value
      # @param tags [Hash] metric tags
      def gauge(metric, value, tags: {})
        if @client.respond_to?(:gauge)
          @client.gauge(metric, value, tags: format_tags(tags))
        end
      end

      private

      def format_tags(tags)
        tags.map { |k, v| "#{k}:#{v}" }
      end
    end

    # Adapter for Datadog StatsD client
    class DatadogAdapter
      def initialize(client)
        @client = client
      end

      # Increment a counter metric
      # @param metric [String] metric name
      # @param value [Integer] value to increment by
      # @param tags [Hash] metric tags
      def increment(metric, value, tags: {})
        if @client.respond_to?(:count)
          @client.count(metric, value, tags: format_tags(tags))
        end
      end

      # Record a timing metric
      # @param metric [String] metric name
      # @param value [Float] timing value in milliseconds
      # @param tags [Hash] metric tags
      def timing(metric, value, tags: {})
        if @client.respond_to?(:timing)
          @client.timing(metric, value, tags: format_tags(tags))
        end
      end

      # Set a gauge metric
      # @param metric [String] metric name
      # @param value [Numeric] gauge value
      # @param tags [Hash] metric tags
      def gauge(metric, value, tags: {})
        if @client.respond_to?(:gauge)
          @client.gauge(metric, value, tags: format_tags(tags))
        end
      end

      private

      def format_tags(tags)
        tags.map { |k, v| "#{k}:#{v}" }
      end
    end

    # Adapter for custom metrics client
    class CustomAdapter
      def initialize(client)
        @client = client
      end

      # Increment a counter metric
      # @param metric [String] metric name
      # @param value [Integer] value to increment by
      # @param tags [Hash] metric tags
      def increment(metric, value, tags: {})
        if @client.respond_to?(:increment)
          @client.increment(metric, value, tags: tags)
        end
      end

      # Record a timing metric
      # @param metric [String] metric name
      # @param value [Float] timing value in milliseconds
      # @param tags [Hash] metric tags
      def timing(metric, value, tags: {})
        if @client.respond_to?(:timing)
          @client.timing(metric, value, tags: tags)
        end
      end

      # Set a gauge metric
      # @param metric [String] metric name
      # @param value [Numeric] gauge value
      # @param tags [Hash] metric tags
      def gauge(metric, value, tags: {})
        if @client.respond_to?(:gauge)
          @client.gauge(metric, value, tags: tags)
        end
      end
    end

    # Null adapter for when metrics are disabled
    class NullAdapter
      # No-op increment
      # @param _metric [String] metric name
      # @param _value [Integer] value to increment by
      # @param tags [Hash] metric tags
      def increment(_metric, _value, tags: {}); end

      # No-op timing
      # @param _metric [String] metric name
      # @param _value [Float] timing value
      # @param tags [Hash] metric tags
      def timing(_metric, _value, tags: {}); end

      # No-op gauge
      # @param _metric [String] metric name
      # @param _value [Numeric] gauge value
      # @param tags [Hash] metric tags
      def gauge(_metric, _value, tags: {}); end
    end
  end
end
