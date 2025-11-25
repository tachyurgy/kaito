# frozen_string_literal: true

module Kaito
  module Tokenizers
    # Simple character-based tokenizer
    # Treats each character as a token - useful for testing or when token-level precision isn't needed
    class Character < Base
      # Count tokens (characters) in text
      # @param text [String] the text to tokenize
      # @return [Integer] the number of characters
      def count(text)
        return 0 if text.nil? || text.empty?

        text.length
      end

      # Encode text into character codes
      # @param text [String] the text to encode
      # @return [Array<Integer>] array of character codes
      def encode(text)
        return [] if text.nil? || text.empty?

        text.chars.map(&:ord)
      end

      # Decode character codes back into text
      # @param tokens [Array<Integer>] array of character codes
      # @return [String] the decoded text
      def decode(tokens)
        return '' if tokens.nil? || tokens.empty?

        tokens.map(&:chr).join
      end

      # Truncate text to fit within max "tokens" (characters)
      # @param text [String] the text to truncate
      # @param max_tokens [Integer] maximum number of characters
      # @return [String] truncated text
      def truncate(text, max_tokens:)
        return text if text.length <= max_tokens

        text[0...max_tokens]
      end
    end
  end
end
