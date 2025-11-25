# frozen_string_literal: true

require_relative 'kaito/version'
require_relative 'kaito/errors'
require_relative 'kaito/chunk'
require_relative 'kaito/tokenizers/base'
require_relative 'kaito/tokenizers/tiktoken'
require_relative 'kaito/tokenizers/character'
require_relative 'kaito/splitters/base'
require_relative 'kaito/splitters/character'
require_relative 'kaito/splitters/semantic'
require_relative 'kaito/splitters/structure_aware'
require_relative 'kaito/splitters/adaptive_overlap'
require_relative 'kaito/splitters/recursive'
require_relative 'kaito/utils/text_utils'
require_relative 'kaito/configuration'
require_relative 'kaito/logger'
require_relative 'kaito/instrumentation'
require_relative 'kaito/metrics'

# Kaito is a production-grade text splitting library for LLM applications.
#
# @example Basic usage
#   chunks = Kaito.split("Your long text here", max_tokens: 512)
#
# @example Advanced usage with semantic splitting
#   splitter = Kaito::SemanticSplitter.new(
#     max_tokens: 1000,
#     overlap_tokens: 100,
#     tokenizer: :gpt4
#   )
#   chunks = splitter.split(text)
#
# @example Streaming large files
#   Kaito.stream_file("large_file.txt", max_tokens: 512) do |chunk|
#     process_chunk(chunk)
#   end
module Kaito
  class << self
    # Global configuration for Kaito
    # @return [Configuration]
    attr_accessor :configuration

    # Configure Kaito with a block
    #
    # @example
    #   Kaito.configure do |config|
    #     config.default_tokenizer = :gpt4
    #     config.default_max_tokens = 512
    #   end
    #
    # @yield [Configuration] configuration object
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Split text using the default or specified strategy
    #
    # @param text [String] the text to split
    # @param strategy [Symbol] the splitting strategy (:character, :semantic, :structure_aware, :adaptive, :recursive)
    # @param max_tokens [Integer] maximum tokens per chunk
    # @param overlap_tokens [Integer] number of tokens to overlap between chunks
    # @param tokenizer [Symbol] tokenizer to use (:gpt35_turbo, :gpt4, :gpt4_turbo, :character)
    # @param options [Hash] additional strategy-specific options
    # @return [Array<Chunk>] array of text chunks
    #
    # @example
    #   chunks = Kaito.split(text, strategy: :semantic, max_tokens: 512, overlap_tokens: 50)
    def split(text, strategy: :semantic, max_tokens: 512, overlap_tokens: 0, tokenizer: :gpt4, **options)
      splitter = create_splitter(strategy, max_tokens: max_tokens, overlap_tokens: overlap_tokens,
                                           tokenizer: tokenizer, **options)
      splitter.split(text)
    end

    # Stream and split a file
    #
    # @param file_path [String] path to the file
    # @param strategy [Symbol] the splitting strategy
    # @param max_tokens [Integer] maximum tokens per chunk
    # @param overlap_tokens [Integer] number of tokens to overlap
    # @param tokenizer [Symbol] tokenizer to use
    # @param options [Hash] additional options
    # @yield [Chunk] each chunk as it's processed
    # @return [Enumerator] if no block given
    #
    # @example
    #   Kaito.stream_file("large.txt", max_tokens: 512) do |chunk|
    #     puts chunk.text
    #   end
    def stream_file(file_path, strategy: :semantic, max_tokens: 512, overlap_tokens: 0, tokenizer: :gpt4, **options,
                    &block)
      splitter = create_splitter(strategy, max_tokens: max_tokens, overlap_tokens: overlap_tokens,
                                           tokenizer: tokenizer, **options)
      splitter.stream_file(file_path, &block)
    end

    # Count tokens in text
    #
    # @param text [String] the text to count tokens for
    # @param tokenizer [Symbol] tokenizer to use
    # @return [Integer] token count
    def count_tokens(text, tokenizer: :gpt4)
      tokenizer_instance = create_tokenizer(tokenizer)
      tokenizer_instance.count(text)
    end

    private

    def create_splitter(strategy, **options)
      case strategy
      when :character
        Splitters::Character.new(**options)
      when :semantic
        Splitters::Semantic.new(**options)
      when :structure_aware
        Splitters::StructureAware.new(**options)
      when :adaptive, :adaptive_overlap
        Splitters::AdaptiveOverlap.new(**options)
      when :recursive
        Splitters::Recursive.new(**options)
      else
        raise ArgumentError, "Unknown strategy: #{strategy}. Valid strategies: :character, :semantic, :structure_aware, :adaptive, :recursive"
      end
    end

    def create_tokenizer(tokenizer_name)
      case tokenizer_name
      when :gpt35_turbo, :gpt4, :gpt4_turbo
        Tokenizers::Tiktoken.new(model: tokenizer_name)
      when :character
        Tokenizers::Character.new
      else
        raise ArgumentError, "Unknown tokenizer: #{tokenizer_name}. Supported: :gpt35_turbo, :gpt4, :gpt4_turbo, :character"
      end
    end
  end

  # Initialize default configuration
  configure
end
