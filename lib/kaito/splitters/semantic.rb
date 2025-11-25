# frozen_string_literal: true

begin
  require 'pragmatic_segmenter'
rescue LoadError
  # pragmatic_segmenter is optional, will fall back to simple splitting
  nil
end

module Kaito
  module Splitters
    # Semantic text splitter that preserves sentence boundaries
    # Uses pragmatic_segmenter for accurate sentence detection when available
    class Semantic < Base
      attr_reader :language, :preserve_sentences, :preserve_paragraphs

      # Initialize a semantic splitter
      #
      # @param max_tokens [Integer] maximum tokens per chunk
      # @param overlap_tokens [Integer] number of tokens to overlap between chunks
      # @param tokenizer [Symbol, Tokenizers::Base] tokenizer to use
      # @param language [Symbol] language for sentence detection (:en, :es, :fr, :de, :ja, :zh, etc.)
      # @param preserve_sentences [Boolean] whether to preserve sentence boundaries
      # @param preserve_paragraphs [Boolean] whether to preserve paragraph boundaries
      def initialize(max_tokens: 512, overlap_tokens: 0, tokenizer: :gpt4, language: :en,
                     preserve_sentences: true, preserve_paragraphs: false, **options)
        super(max_tokens: max_tokens, overlap_tokens: overlap_tokens, tokenizer: tokenizer, **options)
        @language = language
        @preserve_sentences = preserve_sentences
        @preserve_paragraphs = preserve_paragraphs
      end

      # Split text into semantically coherent chunks
      #
      # @param text [String] the text to split
      # @return [Array<Chunk>] array of text chunks
      def perform_split(text)
        return [] if text.nil? || text.empty?

        # Normalize text
        text = Kaito::Utils::TextUtils.clean(text)

        if preserve_paragraphs
          split_by_paragraphs(text)
        elsif preserve_sentences
          split_by_sentences(text)
        else
          # Fall back to character splitting
          Splitters::Character.new(
            max_tokens: max_tokens,
            overlap_tokens: overlap_tokens,
            tokenizer: tokenizer
          ).split(text)
        end
      end

      private

      def split_by_paragraphs(text)
        paragraphs = Kaito::Utils::TextUtils.split_paragraphs(text)
        combine_into_chunks(paragraphs, separator: "\n\n")
      end

      def split_by_sentences(text)
        sentences = segment_sentences(text)
        combine_into_chunks(sentences, separator: ' ')
      end

      def segment_sentences(text)
        if defined?(PragmaticSegmenter)
          segmenter = PragmaticSegmenter::Segmenter.new(text: text, language: language.to_s)
          segmenter.segment
        else
          # Fall back to simple sentence splitting
          Kaito::Utils::TextUtils.simple_sentence_split(text)
        end
      end

      def combine_into_chunks(segments, separator:)
        return [] if segments.empty?

        chunks = []
        current_chunk = []
        current_tokens = 0

        segments.each do |segment|
          segment_tokens = tokenizer.count(segment)

          if segment_tokens > max_tokens
            chunks, current_chunk, current_tokens = handle_oversized_segment(
              segment, chunks, current_chunk, separator
            )
            next
          end

          if should_create_new_chunk?(current_tokens, segment_tokens, current_chunk, separator)
            chunks, current_chunk, current_tokens = finalize_and_overlap(
              chunks, current_chunk, separator
            )
          end

          current_chunk << segment
          current_tokens = calculate_tokens(current_chunk, separator)
        end

        chunks << create_chunk_from_segments(current_chunk, separator, chunks.length) unless current_chunk.empty?
        chunks
      end

      def handle_oversized_segment(segment, chunks, current_chunk, separator)
        chunks << create_chunk_from_segments(current_chunk, separator, chunks.length) unless current_chunk.empty?

        split_large_segment(segment).each { |sub_chunk| chunks << sub_chunk }
        [chunks, [], 0]
      end

      def should_create_new_chunk?(current_tokens, segment_tokens, current_chunk, separator)
        return false if current_chunk.empty?

        potential_tokens = current_tokens + segment_tokens + tokenizer.count(separator)
        potential_tokens > max_tokens
      end

      def finalize_and_overlap(chunks, current_chunk, separator)
        chunks << create_chunk_from_segments(current_chunk, separator, chunks.length)

        overlap_segments = calculate_overlap_segments(current_chunk, separator)
        current_chunk = overlap_segments.dup
        current_tokens = calculate_tokens(current_chunk, separator)

        [chunks, current_chunk, current_tokens]
      end

      def create_chunk_from_segments(segments, separator, index)
        text = segments.join(separator)
        Chunk.new(
          text,
          metadata: { index: index, segment_count: segments.length },
          token_count: tokenizer.count(text)
        )
      end

      def calculate_tokens(segments, separator)
        return 0 if segments.empty?

        text = segments.join(separator)
        tokenizer.count(text)
      end

      def calculate_overlap_segments(segments, separator)
        return [] if overlap_tokens.zero? || segments.empty?

        overlap_segs = []
        tokens = 0

        # Take segments from the end until we reach overlap_tokens
        segments.reverse_each do |segment|
          segment_tokens = tokenizer.count(segment)
          break unless tokens + segment_tokens <= overlap_tokens

          overlap_segs.unshift(segment)
          tokens += segment_tokens
          tokens += tokenizer.count(separator) if overlap_segs.length > 1
        end

        overlap_segs
      end

      def split_large_segment(segment)
        # Use character splitter for segments that are too large
        char_splitter = Splitters::Character.new(
          max_tokens: max_tokens,
          overlap_tokens: 0,
          tokenizer: tokenizer
        )
        char_splitter.split(segment)
      end
    end
  end
end
