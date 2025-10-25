# frozen_string_literal: true

module Kaito
  module Tokenizers
    # Base class for all tokenizers
    class Base
      # Count tokens in text
      # @param text [String] the text to tokenize
      # @return [Integer] the number of tokens
      # @raise [NotImplementedError] must be implemented by subclasses
      def count(text)
        raise NotImplementedError, "#{self.class} must implement #count"
      end

      # Encode text into tokens
      # @param text [String] the text to tokenize
      # @return [Array<Integer>] array of token IDs
      # @raise [NotImplementedError] must be implemented by subclasses
      def encode(text)
        raise NotImplementedError, "#{self.class} must implement #encode"
      end

      # Decode tokens back into text
      # @param tokens [Array<Integer>] array of token IDs
      # @return [String] the decoded text
      # @raise [NotImplementedError] must be implemented by subclasses
      def decode(tokens)
        raise NotImplementedError, "#{self.class} must implement #decode"
      end

      # Truncate text to fit within max tokens
      # @param text [String] the text to truncate
      # @param max_tokens [Integer] maximum number of tokens
      # @return [String] truncated text
      def truncate(text, max_tokens:)
        token_count = count(text)
        return text if token_count <= max_tokens

        # Binary search for the right length
        min_len = 0
        max_len = text.length
        result = ""

        while min_len <= max_len
          mid = (min_len + max_len) / 2
          candidate = text[0...mid]
          tokens = count(candidate)

          if tokens <= max_tokens
            result = candidate
            min_len = mid + 1
          else
            max_len = mid - 1
          end
        end

        result
      end
    end
  end
end
