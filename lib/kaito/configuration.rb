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

    # @return [Boolean] whether to enable concurrent processing
    attr_accessor :enable_concurrency

    # @return [Integer] number of workers for concurrent processing
    attr_accessor :concurrency_workers

    # @return [Boolean] whether to cache tokenization results
    attr_accessor :cache_tokenization

    def initialize
      @default_tokenizer = :gpt4
      @default_max_tokens = 512
      @default_overlap_tokens = 0
      @default_strategy = :semantic
      @preserve_sentences = true
      @default_language = :en
      @enable_concurrency = false
      @concurrency_workers = 4
      @cache_tokenization = true
    end

    # Validate configuration
    # @raise [ConfigurationError] if configuration is invalid
    def validate!
      raise ConfigurationError, "max_tokens must be positive" if default_max_tokens <= 0
      raise ConfigurationError, "overlap_tokens cannot be negative" if default_overlap_tokens < 0
      raise ConfigurationError, "overlap must be less than max_tokens" if default_overlap_tokens >= default_max_tokens
      raise ConfigurationError, "concurrency_workers must be positive" if concurrency_workers <= 0

      true
    end
  end
end
