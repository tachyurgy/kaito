# frozen_string_literal: true

begin
  require "tiktoken_ruby"
rescue LoadError
  # tiktoken_ruby is optional
  nil
end

module Kaito
  module Tokenizers
    # Tiktoken-based tokenizer for accurate token counting
    # Supports GPT-3.5, GPT-4, and other OpenAI models
    class Tiktoken < Base
      # Model to encoding mapping
      # Note: Claude uses cl100k_base as an APPROXIMATION only.
      # Anthropic uses a different tokenizer, so counts may not be exact.
      # For production Claude usage, consider using a character-based fallback
      # or implementing a proper Claude tokenizer when available.
      MODEL_ENCODINGS = {
        gpt35_turbo: "cl100k_base",
        gpt4: "cl100k_base",
        gpt4_turbo: "cl100k_base",
        claude: "cl100k_base", # APPROXIMATE - Claude has different tokenizer
        text_davinci_003: "p50k_base",
        text_davinci_002: "p50k_base",
        code_davinci_002: "p50k_base"
      }.freeze

      attr_reader :encoding_name, :encoder

      # Initialize a tiktoken tokenizer
      # @param model [Symbol, String] the model name or encoding name
      def initialize(model: :gpt4)
        ensure_tiktoken_available!

        @encoding_name = MODEL_ENCODINGS[model.to_sym] || model.to_s
        @encoder = ::Tiktoken.get_encoding(@encoding_name)
        @cache = {} if Kaito.configuration.cache_tokenization
      rescue StandardError => e
        raise TokenizationError, "Failed to initialize tiktoken: #{e.message}"
      end

      # Count tokens in text
      # @param text [String] the text to tokenize
      # @return [Integer] the number of tokens
      def count(text)
        return 0 if text.nil? || text.empty?

        if @cache
          @cache[text] ||= encoder.encode(text).length
        else
          encoder.encode(text).length
        end
      rescue StandardError => e
        raise TokenizationError, "Failed to count tokens: #{e.message}"
      end

      # Encode text into tokens
      # @param text [String] the text to tokenize
      # @return [Array<Integer>] array of token IDs
      def encode(text)
        return [] if text.nil? || text.empty?

        encoder.encode(text)
      rescue StandardError => e
        raise TokenizationError, "Failed to encode text: #{e.message}"
      end

      # Decode tokens back into text
      # @param tokens [Array<Integer>] array of token IDs
      # @return [String] the decoded text
      def decode(tokens)
        return "" if tokens.nil? || tokens.empty?

        encoder.decode(tokens)
      rescue StandardError => e
        raise TokenizationError, "Failed to decode tokens: #{e.message}"
      end

      # Truncate text to fit within max tokens
      # @param text [String] the text to truncate
      # @param max_tokens [Integer] maximum number of tokens
      # @return [String] truncated text
      def truncate(text, max_tokens:)
        tokens = encode(text)
        return text if tokens.length <= max_tokens

        decode(tokens[0...max_tokens])
      end

      # Clear the tokenization cache
      def clear_cache!
        @cache&.clear
      end

      private

      def ensure_tiktoken_available!
        return if defined?(::Tiktoken)

        raise TokenizationError, "tiktoken_ruby gem is not available. Install it with: gem install tiktoken_ruby"
      end
    end
  end
end
