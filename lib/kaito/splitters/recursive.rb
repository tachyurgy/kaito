# frozen_string_literal: true

module Kaito
  module Splitters
    # Recursive text splitter similar to LangChain's RecursiveCharacterTextSplitter
    # Tries to split on progressively smaller separators to maintain structure
    class Recursive < Base
      # Default list of separators in order of preference
      DEFAULT_SEPARATORS = [
        "\n\n",   # Paragraphs
        "\n",     # Lines
        '. ',     # Sentences
        '! ',     # Exclamations
        '? ',     # Questions
        '; ',     # Semicolons
        ', ',     # Clauses
        ' ',      # Words
        ''        # Characters
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
      def perform_split(text)
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
        return [text] if seps.empty?
        return text.chars if seps[0].empty?

        separator = seps[0]
        remaining_seps = seps[1..]

        return split_text(text, remaining_seps) unless text.include?(separator)

        process_text_parts(text, separator, remaining_seps)
      end

      def process_text_parts(text, separator, remaining_seps)
        parts = text.split(separator, -1)
        splits = []

        parts.each_with_index do |part, i|
          part = add_separator_if_needed(part, separator, i, parts.length)
          splits.concat(process_single_part(part, remaining_seps))
        end

        splits
      end

      def add_separator_if_needed(part, separator, index, total_parts)
        return part unless keep_separator && index < total_parts - 1

        part + separator
      end

      def process_single_part(part, remaining_seps)
        return [] if part.empty?
        return [part] if tokenizer.count(part) <= max_tokens

        split_text(part, remaining_seps)
      end

      def merge_splits(splits)
        return [] if splits.empty?

        chunks = []
        current_chunk = []
        current_tokens = 0

        splits.each do |split|
          split_tokens = tokenizer.count(split)

          if split_tokens > max_tokens
            chunks, current_chunk, current_tokens = handle_oversized_split(
              split, chunks, current_chunk, current_tokens
            )
            next
          end

          if should_flush_chunk?(current_tokens, split_tokens, current_chunk)
            chunks, current_chunk, current_tokens = flush_chunk_with_overlap(chunks, current_chunk)
          end

          current_chunk << split
          current_tokens += split_tokens
        end

        chunks << current_chunk.join unless current_chunk.empty?
        chunks
      end

      def handle_oversized_split(split, chunks, current_chunk, current_tokens)
        unless current_chunk.empty?
          chunks << current_chunk.join
          current_chunk = []
          current_tokens = 0
        end

        chunks << split
        [chunks, current_chunk, current_tokens]
      end

      def should_flush_chunk?(current_tokens, split_tokens, current_chunk)
        (current_tokens + split_tokens > max_tokens) && !current_chunk.empty?
      end

      def flush_chunk_with_overlap(chunks, current_chunk)
        chunks << current_chunk.join

        if overlap_tokens.positive?
          overlap_splits = calculate_overlap_splits(current_chunk)
          current_tokens = overlap_splits.sum { |s| tokenizer.count(s) }
          [chunks, overlap_splits, current_tokens]
        else
          [chunks, [], 0]
        end
      end

      def calculate_overlap_splits(splits)
        return [] if overlap_tokens.zero? || splits.empty?

        overlap_splits = []
        tokens = 0

        splits.reverse_each do |split|
          split_tokens = tokenizer.count(split)

          break unless tokens + split_tokens <= overlap_tokens

          overlap_splits.unshift(split)
          tokens += split_tokens
        end

        overlap_splits
      end
    end
  end
end
