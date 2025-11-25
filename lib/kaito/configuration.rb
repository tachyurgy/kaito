# frozen_string_literal: true

module Kaito
  # Global configuration for Kaito
  class Configuration
    # @return [Symbol] default tokenizer to use
    attr_accessor :default_tokenizer

    # @return [Integer] default maximum tokens per chunk
    attr_accessor :default_max_tokens

    # @return [Integer] default overlap tokens
    attr_accessor :default_overlap_tokens

    # @return [Symbol] default splitting strategy
    attr_accessor :default_strategy

    # @return [Boolean] whether to preserve sentence boundaries by default
    attr_accessor :preserve_sentences

    # @return [Symbol] default language for text processing
    attr_accessor :default_language

    # @return [Boolean] whether to cache tokenization results
    attr_accessor :cache_tokenization

    # @return [Logger, nil] logger instance for structured logging
    attr_accessor :logger

    # @return [Metrics, nil] metrics instance for tracking operations
    attr_accessor :metrics

    # @return [Boolean] whether to enable instrumentation
    attr_accessor :instrumentation_enabled

    def initialize
      @default_tokenizer = :gpt4
      @default_max_tokens = 512
      @default_overlap_tokens = 0
      @default_strategy = :semantic
      @preserve_sentences = true
      @default_language = :en
      @cache_tokenization = true
      @logger = nil
      @metrics = nil
      @instrumentation_enabled = false
    end

    # Validate configuration
    # @raise [ConfigurationError] if configuration is invalid
    def validate! # rubocop:disable Naming/PredicateMethod
      raise ConfigurationError, 'max_tokens must be positive' if default_max_tokens <= 0
      raise ConfigurationError, 'overlap_tokens cannot be negative' if default_overlap_tokens.negative?
      raise ConfigurationError, 'overlap must be less than max_tokens' if default_overlap_tokens >= default_max_tokens

      true
    end
  end
end
