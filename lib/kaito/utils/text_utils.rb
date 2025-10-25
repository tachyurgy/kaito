# frozen_string_literal: true

require "unicode_utils/nfkc"

module Kaito
  module Utils
    # Text utility functions
    module TextUtils
      # Normalize Unicode text
      # @param text [String]
      # @return [String]
      def self.normalize(text)
        UnicodeUtils.nfkc(text)
      end

      # Clean and normalize text for processing
      # @param text [String]
      # @param remove_extra_whitespace [Boolean]
      # @return [String]
      def self.clean(text, remove_extra_whitespace: true)
        normalized = normalize(text)
        return normalized unless remove_extra_whitespace

        # Remove extra whitespace while preserving paragraph breaks
        normalized.gsub(/[^\S\n]+/, " ")           # Replace multiple spaces/tabs with single space
                  .gsub(/ *\n */, "\n")            # Remove spaces around newlines
                  .gsub(/\n{3,}/, "\n\n")          # Max 2 consecutive newlines
                  .strip
      end

      # Split text into sentences using simple heuristics
      # @param text [String]
      # @return [Array<String>]
      def self.simple_sentence_split(text)
        # Simple sentence boundary detection
        # This is a fallback for when pragmatic_segmenter is not available
        sentences = []
        current = ""

        text.scan(/[^.!?]+[.!?]+|[^.!?]+$/) do |match|
          current += match
          # Check if this looks like a sentence ending
          if match =~ /[.!?]+$/ && !match.match?(/\b[A-Z][a-z]?\.$/) # Not an abbreviation
            sentences << current.strip
            current = ""
          end
        end

        sentences << current.strip unless current.strip.empty?
        sentences
      end

      # Split text into paragraphs
      # @param text [String]
      # @return [Array<String>]
      def self.split_paragraphs(text)
        text.split(/\n\n+/).map(&:strip).reject(&:empty?)
      end

      # Split text into lines
      # @param text [String]
      # @return [Array<String>]
      def self.split_lines(text)
        text.split(/\n/).map(&:strip)
      end

      # Check if text appears to be code
      # @param text [String]
      # @return [Boolean]
      def self.code?(text)
        # Simple heuristics: high ratio of special characters, indentation patterns
        lines = text.split("\n")
        return false if lines.empty?

        # Check for common code patterns
        code_indicators = [
          /^\s*(def|class|module|function|const|let|var|import|export|public|private)\s/,
          /[{}\[\]();].*[{}\[\]();]/, # Multiple brackets/parens
          /^\s{2,}/, # Significant indentation
          /=>|->|==|!=|<=|>=/ # Operators
        ]

        code_line_count = lines.count { |line| code_indicators.any? { |pattern| line.match?(pattern) } }
        code_line_count.to_f / lines.length > 0.3
      end

      # Check if text is markdown
      # @param text [String]
      # @return [Boolean]
      def self.markdown?(text)
        markdown_patterns = [
          /^\#{1,6}\s/, # Headers
          /^\*\*|__/, # Bold
          /^\*|^-|^\d+\./, # Lists
          /```/, # Code blocks
          /\[.*\]\(.*\)/ # Links
        ]

        lines = text.split("\n")
        markdown_line_count = lines.count { |line| markdown_patterns.any? { |pattern| line.match?(pattern) } }
        markdown_line_count > 0
      end

      # Extract the overlap between two strings
      # @param str1 [String] first string
      # @param str2 [String] second string
      # @param min_overlap [Integer] minimum overlap to consider
      # @return [String, nil] the overlapping portion or nil
      def self.find_overlap(str1, str2, min_overlap: 10)
        return nil if str1.empty? || str2.empty?

        max_len = [str1.length, str2.length].min
        (max_len).downto(min_overlap) do |length|
          suffix = str1[-length..-1]
          prefix = str2[0...length]
          return suffix if suffix == prefix
        end

        nil
      end

      # Calculate similarity between two strings (simple Jaccard similarity)
      # @param str1 [String]
      # @param str2 [String]
      # @return [Float] similarity score between 0 and 1
      def self.similarity(str1, str2)
        return 1.0 if str1 == str2
        return 0.0 if str1.empty? || str2.empty?

        words1 = str1.downcase.split
        words2 = str2.downcase.split

        return 0.0 if words1.empty? || words2.empty?

        intersection = (words1 & words2).length
        union = (words1 | words2).length

        intersection.to_f / union
      end

      # Truncate text to a maximum length, trying to break at word boundaries
      # @param text [String]
      # @param max_length [Integer]
      # @param suffix [String] suffix to add if truncated
      # @return [String]
      def self.truncate(text, max_length:, suffix: "...")
        return text if text.length <= max_length

        truncated_length = max_length - suffix.length
        truncated = text[0...truncated_length]

        # Try to break at last space
        last_space = truncated.rindex(" ")
        truncated = truncated[0...last_space] if last_space

        truncated + suffix
      end
    end
  end
end
