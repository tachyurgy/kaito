# frozen_string_literal: true

module Kaito
  module Splitters
    # Recursive text splitter similar to LangChain's RecursiveCharacterTextSplitter
    # Tries to split on progressively smaller separators to maintain structure
    class Recursive < Base
      DEFAULT_SEPARATORS = [
        "\n\n",   # Paragraphs
        "\n",     # Lines
        ". ",     # Sentences
        "! ",     # Exclamations
        "? ",     # Questions
        "; ",     # Semicolons
        ", ",     # Clauses
        " ",      # Words
        ""        # Characters
      ].freeze

      attr_reader :separators, :keep_separator

      # Initialize a recursive splitter
      #
      # @param max_tokens [Integer] maximum tokens per chunk
      # @param overlap_tokens [Integer] number of tokens to overlap between chunks
      # @param tokenizer [Symbol, Tokenizers::Base] tokenizer to use
      # @param separators [Array<String>] list of separators in order of preference
      # @param keep_separator [Boolean] whether to keep separators in the chunks
      def initialize(max_tokens: 512, overlap_tokens: 0, tokenizer: :gpt4,
                     separators: DEFAULT_SEPARATORS, keep_separator: true, **options)
        super(max_tokens: max_tokens, overlap_tokens: overlap_tokens, tokenizer: tokenizer, **options)
        @separators = separators
        @keep_separator = keep_separator
      end

      # Split text recursively using progressively smaller separators
      #
      # @param text [String] the text to split
      # @return [Array<Chunk>] array of text chunks
      def split(text)
        return [] if text.nil? || text.empty?

        splits = split_text(text, separators)
        chunks = merge_splits(splits)

        # Add metadata and create Chunk objects
        chunks.map.with_index do |chunk_text, index|
          Chunk.new(
            chunk_text,
            metadata: { index: index },
            token_count: tokenizer.count(chunk_text)
          )
        end
      end

      private

      def split_text(text, seps)
        # Base case: no more separators, return character splits
        if seps.empty?
          return [text]
        end

        separator = seps[0]
        remaining_seps = seps[1..-1]

        # Try to split on this separator
        if separator.empty?
          # Character-level split
          return text.chars
        end

        splits = []
        if text.include?(separator)
          parts = text.split(separator, -1) # -1 to keep trailing empty strings

          parts.each_with_index do |part, i|
            # Add separator back if keep_separator is true (except for last part)
            if keep_separator && i < parts.length - 1
              part += separator
            end

            # Recursively split this part if it's still too large
            if tokenizer.count(part) > max_tokens
              sub_splits = split_text(part, remaining_seps)
              splits.concat(sub_splits)
            else
              splits << part unless part.empty?
            end
          end
        else
          # Separator not found, try next separator
          splits = split_text(text, remaining_seps)
        end

        splits
      end

      def merge_splits(splits)
        return [] if splits.empty?

        chunks = []
        current_chunk = []
        current_tokens = 0

        splits.each do |split|
          split_tokens = tokenizer.count(split)

          # If a single split exceeds max_tokens, we need to force it into a chunk
          if split_tokens > max_tokens
            # Flush current chunk first
            unless current_chunk.empty?
              chunks << current_chunk.join("")
              current_chunk = []
              current_tokens = 0
            end

            # Add the oversized split as its own chunk (unavoidable)
            chunks << split
            next
          end

          # Check if adding this split would exceed max_tokens
          potential_tokens = current_tokens + split_tokens

          if potential_tokens > max_tokens && !current_chunk.empty?
            # Create chunk from current splits
            chunk_text = current_chunk.join("")
            chunks << chunk_text

            # Handle overlap
            if overlap_tokens > 0
              overlap_splits = calculate_overlap_splits(current_chunk)
              current_chunk = overlap_splits
              current_tokens = current_chunk.sum { |s| tokenizer.count(s) }
            else
              current_chunk = []
              current_tokens = 0
            end
          end

          current_chunk << split
          current_tokens += split_tokens
        end

        # Add final chunk
        unless current_chunk.empty?
          chunks << current_chunk.join("")
        end

        chunks
      end

      def calculate_overlap_splits(splits)
        return [] if overlap_tokens == 0 || splits.empty?

        overlap_splits = []
        tokens = 0

        splits.reverse_each do |split|
          split_tokens = tokenizer.count(split)

          if tokens + split_tokens <= overlap_tokens
            overlap_splits.unshift(split)
            tokens += split_tokens
          else
            break
          end
        end

        overlap_splits
      end
    end
  end
end
