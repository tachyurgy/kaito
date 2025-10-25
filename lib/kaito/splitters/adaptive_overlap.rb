# frozen_string_literal: true

module Kaito
  module Splitters
    # Adaptive overlap splitter that intelligently determines overlap
    # based on content similarity and semantic boundaries
    class AdaptiveOverlap < Base
      attr_reader :min_overlap_tokens, :max_overlap_tokens, :similarity_threshold

      # Initialize an adaptive overlap splitter
      #
      # @param max_tokens [Integer] maximum tokens per chunk
      # @param overlap_tokens [Integer] target overlap tokens (used as default)
      # @param min_overlap_tokens [Integer] minimum overlap tokens
      # @param max_overlap_tokens [Integer] maximum overlap tokens
      # @param similarity_threshold [Float] minimum similarity for overlap (0.0-1.0)
      # @param tokenizer [Symbol, Tokenizers::Base] tokenizer to use
      def initialize(max_tokens: 512, overlap_tokens: 50, min_overlap_tokens: 20,
                     max_overlap_tokens: 100, similarity_threshold: 0.3, tokenizer: :gpt4, **options)
        @min_overlap_tokens = min_overlap_tokens
        @max_overlap_tokens = max_overlap_tokens
        @similarity_threshold = similarity_threshold

        super(max_tokens: max_tokens, overlap_tokens: overlap_tokens, tokenizer: tokenizer, **options)
      end

      # Split text with adaptive overlap
      #
      # @param text [String] the text to split
      # @return [Array<Chunk>] array of text chunks
      def split(text)
        return [] if text.nil? || text.empty?

        # First, split using semantic splitter without overlap
        semantic_splitter = Splitters::Semantic.new(
          max_tokens: max_tokens,
          overlap_tokens: 0,
          tokenizer: tokenizer
        )

        initial_chunks = semantic_splitter.split(text)
        return initial_chunks if initial_chunks.length <= 1

        # Add adaptive overlap between chunks
        add_adaptive_overlap(initial_chunks)
      end

      private

      def add_adaptive_overlap(chunks)
        result = []
        result << chunks.first

        (1...chunks.length).each do |i|
          prev_chunk = chunks[i - 1]
          current_chunk = chunks[i]

          # Calculate optimal overlap
          overlap_text = calculate_optimal_overlap(prev_chunk.text, current_chunk.text)

          # Create new chunk with overlap prepended
          new_text = overlap_text.empty? ? current_chunk.text : "#{overlap_text} #{current_chunk.text}"

          metadata = current_chunk.metadata.merge(
            overlap_tokens: tokenizer.count(overlap_text),
            adaptive_overlap: true
          )

          result << Chunk.new(
            new_text,
            metadata: metadata,
            token_count: tokenizer.count(new_text)
          )
        end

        # Re-index
        result.each_with_index do |chunk, idx|
          chunk.instance_variable_set(:@metadata, chunk.metadata.merge(index: idx).freeze)
        end

        result
      end

      def calculate_optimal_overlap(prev_text, current_text)
        # Try to find natural overlap point using sentences
        prev_sentences = segment_into_sentences(prev_text)
        return "" if prev_sentences.empty?

        # Start with target overlap and adjust based on content
        target_overlap = overlap_tokens

        # Collect sentences from end of previous chunk
        overlap_sentences = []
        overlap_token_count = 0

        prev_sentences.reverse_each do |sentence|
          sentence_tokens = tokenizer.count(sentence)

          # Check if adding this sentence would exceed max overlap
          if overlap_token_count + sentence_tokens > max_overlap_tokens
            break
          end

          # Check if we should include this sentence based on similarity
          if should_include_in_overlap?(sentence, current_text, overlap_token_count, target_overlap)
            overlap_sentences.unshift(sentence)
            overlap_token_count += sentence_tokens

            # Stop if we've reached target and have good similarity
            if overlap_token_count >= target_overlap
              break
            end
          else
            # If similarity is too low and we have minimum overlap, stop
            break if overlap_token_count >= min_overlap_tokens
          end
        end

        overlap_sentences.join(" ")
      end

      def should_include_in_overlap?(sentence, next_text, current_overlap, target_overlap)
        # Always include if we're below minimum
        return true if current_overlap < min_overlap_tokens

        # Calculate similarity between sentence and start of next text
        next_preview = next_text[0...200] # Look at first 200 chars of next chunk
        similarity = Kaito::Utils::TextUtils.similarity(sentence, next_preview)

        # Include if similarity is above threshold
        similarity >= similarity_threshold
      end

      def segment_into_sentences(text)
        if defined?(PragmaticSegmenter)
          segmenter = PragmaticSegmenter::Segmenter.new(text: text)
          segmenter.segment
        else
          Kaito::Utils::TextUtils.simple_sentence_split(text)
        end
      end
    end
  end
end
