# frozen_string_literal: true

module Kaito
  # Namespace for text splitting strategies
  module Splitters
    # Base class for all text splitters
    class Base
      # Buffer size multiplier for file streaming
      BUFFER_SIZE_MULTIPLIER = 2
      # Percentage of text to consider for overlap calculation
      OVERLAP_SEARCH_PERCENTAGE = 10

      attr_reader :max_tokens, :overlap_tokens, :tokenizer, :min_tokens

      # Initialize a splitter
      #
      # @param max_tokens [Integer] maximum tokens per chunk
      # @param overlap_tokens [Integer] number of tokens to overlap between chunks
      # @param min_tokens [Integer] minimum tokens per chunk (defaults to 0)
      # @param tokenizer [Symbol, Tokenizers::Base] tokenizer to use
      def initialize(max_tokens: 512, overlap_tokens: 0, min_tokens: 0, tokenizer: :gpt4)
        @max_tokens = max_tokens
        @overlap_tokens = overlap_tokens
        @min_tokens = min_tokens
        @tokenizer = create_tokenizer(tokenizer)

        validate_parameters!
      end

      # Split text into chunks
      #
      # @param text [String] the text to split
      # @return [Array<Chunk>] array of text chunks
      # @raise [NotImplementedError] must be implemented by subclasses
      def split(text)
        strategy_name = self.class.name.split('::').last.downcase.to_sym
        text_length = text&.length || 0
        start_time = Time.now

        begin
          result = if instrumentation_enabled?
                    Instrumentation.instrument_split(
                      strategy: strategy_name,
                      text_length: text_length,
                      max_tokens: max_tokens,
                      overlap_tokens: overlap_tokens
                    ) { perform_split(text) }
                  else
                    perform_split(text)
                  end

          duration = Time.now - start_time
          log_split_operation(strategy_name, duration, result, text_length)
          track_split_metrics(strategy_name, duration, result)

          result
        rescue StandardError => e
          log_error('Split operation failed', e, strategy: strategy_name)
          track_error('split', e)
          raise
        end
      end

      # Perform the actual split operation
      # Subclasses should implement this instead of split
      #
      # @param text [String] the text to split
      # @return [Array<Chunk>] array of text chunks
      def perform_split(text)
        raise NotImplementedError, "#{self.class} must implement #perform_split"
      end

      # Stream a file and split it into chunks
      #
      # @param file_path [String] path to the file
      # @yield [Chunk] each chunk as it's processed
      # @return [Enumerator] if no block given
      def stream_file(file_path, &block)
        raise FileError, "File not found: #{file_path}" unless File.exist?(file_path)

        enumerator = create_file_enumerator(file_path)
        return enumerator unless block

        enumerator.each(&block)
      end

      private

      def create_file_enumerator(file_path)
        Enumerator.new do |yielder|
          process_file_in_chunks(file_path, yielder)
        end
      end

      def process_file_in_chunks(file_path, yielder)
        File.open(file_path, 'r') do |file|
          buffer = ''
          chunk_index = 0

          file.each_line do |line|
            buffer += line
            next unless should_process_buffer?(buffer)

            chunks = split(buffer)
            chunk_index = yield_chunks(chunks, yielder, chunk_index, file_path)
            buffer = chunks.last&.text || ''
          end

          yield_remaining_buffer(buffer, yielder, chunk_index, file_path) unless buffer.strip.empty?
        end
      end

      def should_process_buffer?(buffer)
        tokenizer.count(buffer) > max_tokens * BUFFER_SIZE_MULTIPLIER
      end

      def yield_chunks(chunks, yielder, chunk_index, file_path)
        chunks.each do |chunk|
          updated_chunk = create_chunk_with_metadata(chunk, chunk_index, file_path)
          yielder << updated_chunk
          chunk_index += 1
        end
        chunk_index
      end

      def create_chunk_with_metadata(chunk, index, file_path)
        updated_metadata = chunk.metadata.merge(
          index: index,
          source_file: file_path
        )
        Chunk.new(chunk.text, metadata: updated_metadata, token_count: chunk.token_count)
      end

      def yield_remaining_buffer(buffer, yielder, chunk_index, file_path)
        chunks = split(buffer)
        yield_chunks(chunks, yielder, chunk_index, file_path)
      end

      # Count tokens in text using the configured tokenizer
      #
      # @param text [String]
      # @return [Integer]
      def count_tokens(text)
        tokenizer.count(text)
      end

      protected

      # Re-index chunks by creating new chunk objects with updated index metadata
      #
      # @param chunks [Array<Chunk>] chunks to reindex
      # @return [Array<Chunk>] new chunks with updated indices
      def reindex_chunks(chunks)
        chunks.map.with_index do |chunk, idx|
          Chunk.new(
            chunk.text,
            metadata: chunk.metadata.merge(index: idx),
            token_count: chunk.token_count
          )
        end
      end

      # Create chunks with metadata
      #
      # @param texts [Array<String>] array of text strings
      # @param start_offsets [Array<Integer>] optional start offsets
      # @return [Array<Chunk>]
      def create_chunks(texts, start_offsets: nil)
        texts.each_with_index.map do |text, index|
          metadata = { index: index }
          metadata[:start_offset] = start_offsets[index] if start_offsets
          metadata[:end_offset] = start_offsets[index] + text.length if start_offsets

          Chunk.new(
            text,
            metadata: metadata,
            token_count: tokenizer.count(text)
          )
        end
      end

      # Split text at position with overlap
      #
      # @param text [String]
      # @param position [Integer] where to split
      # @return [Array(String, String)] two parts of the split
      def split_with_overlap(text, position)
        overlap_text = calculate_overlap_text(text, position)
        first_part = text[0...position]
        second_part = overlap_text + text[position..]

        [first_part, second_part]
      end

      def calculate_overlap_text(text, position)
        return '' unless overlap_tokens.positive? && position.positive?

        overlap_start = [0, position - (text.length / OVERLAP_SEARCH_PERCENTAGE)].max
        overlap_candidate = text[overlap_start...position]

        return overlap_candidate if tokenizer.count(overlap_candidate) <= overlap_tokens

        binary_search_overlap(text, overlap_start, position)
      end

      def binary_search_overlap(text, min_pos, max_pos)
        overlap_text = ''
        while min_pos < max_pos
          mid = (min_pos + max_pos) / 2
          candidate = text[mid...max_pos]

          if tokenizer.count(candidate) <= overlap_tokens
            overlap_text = candidate
            min_pos = mid + 1
          else
            max_pos = mid
          end
        end
        overlap_text
      end

      private

      def create_tokenizer(tokenizer_spec)
        return tokenizer_spec if tokenizer_spec.is_a?(Tokenizers::Base)

        case tokenizer_spec
        when :gpt35_turbo, :gpt4, :gpt4_turbo
          Tokenizers::Tiktoken.new(model: tokenizer_spec)
        when :character
          Tokenizers::Character.new
        else
          raise ArgumentError, "Unknown tokenizer: #{tokenizer_spec}. Supported: :gpt35_turbo, :gpt4, :gpt4_turbo, :character"
        end
      end

      def validate_parameters!
        raise ArgumentError, 'max_tokens must be positive' if max_tokens <= 0
        raise ArgumentError, 'overlap_tokens cannot be negative' if overlap_tokens.negative?
        raise ArgumentError, 'overlap_tokens must be less than max_tokens' if overlap_tokens >= max_tokens
        raise ArgumentError, 'min_tokens cannot be negative' if min_tokens.negative?
      end

      # Observability helpers

      def instrumentation_enabled?
        Kaito.configuration&.instrumentation_enabled && Instrumentation.enabled?
      end

      def logger
        Kaito.configuration&.logger
      end

      def metrics
        Kaito.configuration&.metrics
      end

      def log_split_operation(strategy, duration, result, text_length)
        return unless logger

        logger.log_split(
          strategy: strategy,
          duration: duration,
          chunks: result.size,
          tokens_processed: result.sum(&:token_count),
          text_length: text_length
        )
      end

      def track_split_metrics(strategy, duration, result)
        return unless metrics

        metrics.track_split(
          strategy: strategy,
          duration: duration,
          chunks: result.size,
          tokens: result.sum(&:token_count)
        )
      end

      def log_error(message, error, **metadata)
        return unless logger

        logger.log_error(message, error: error, **metadata)
      end

      def track_error(operation, error)
        return unless metrics

        metrics.track_error(
          operation: operation,
          error_type: error.class.name
        )
      end
    end
  end
end
