# frozen_string_literal: true

module Kaito
  module Splitters
    # Base class for all text splitters
    class Base
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
        raise NotImplementedError, "#{self.class} must implement #split"
      end

      # Stream a file and split it into chunks
      #
      # @param file_path [String] path to the file
      # @yield [Chunk] each chunk as it's processed
      # @return [Enumerator] if no block given
      def stream_file(file_path, &block)
        raise FileError, "File not found: #{file_path}" unless File.exist?(file_path)

        enumerator = Enumerator.new do |yielder|
          File.open(file_path, "r") do |file|
            buffer = ""
            chunk_index = 0

            file.each_line do |line|
              buffer += line

              # Process buffer when it's large enough
              if tokenizer.count(buffer) > max_tokens * 2
                chunks = split(buffer)
                chunks.each do |chunk|
                  chunk.instance_variable_set(:@metadata, chunk.metadata.merge(
                    index: chunk_index,
                    source_file: file_path
                  ).freeze)
                  yielder << chunk
                  chunk_index += 1
                end

                # Keep overlap for next iteration
                buffer = chunks.last&.text || ""
              end
            end

            # Process remaining buffer
            unless buffer.strip.empty?
              chunks = split(buffer)
              chunks.each do |chunk|
                chunk.instance_variable_set(:@metadata, chunk.metadata.merge(
                  index: chunk_index,
                  source_file: file_path
                ).freeze)
                yielder << chunk
                chunk_index += 1
              end
            end
          end
        end

        return enumerator unless block

        enumerator.each(&block)
      end

      # Count tokens in text using the configured tokenizer
      #
      # @param text [String]
      # @return [Integer]
      def count_tokens(text)
        tokenizer.count(text)
      end

      protected

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
        # Calculate overlap position
        overlap_text = ""
        if overlap_tokens > 0 && position > 0
          # Try to get overlap_tokens worth of text before the split
          overlap_start = [0, position - (text.length / 10)].max # Rough estimate
          overlap_candidate = text[overlap_start...position]

          # Binary search for exact overlap amount
          if tokenizer.count(overlap_candidate) > overlap_tokens
            min_pos = overlap_start
            max_pos = position
            while min_pos < max_pos
              mid = (min_pos + max_pos) / 2
              candidate = text[mid...position]
              if tokenizer.count(candidate) <= overlap_tokens
                overlap_text = candidate
                min_pos = mid + 1
              else
                max_pos = mid
              end
            end
          else
            overlap_text = overlap_candidate
          end
        end

        first_part = text[0...position]
        second_part = overlap_text + text[position..-1]

        [first_part, second_part]
      end

      private

      def create_tokenizer(tokenizer_spec)
        return tokenizer_spec if tokenizer_spec.is_a?(Tokenizers::Base)

        case tokenizer_spec
        when :gpt35_turbo, :gpt4, :gpt4_turbo, :claude
          Tokenizers::Tiktoken.new(model: tokenizer_spec)
        when :character
          Tokenizers::Character.new
        else
          raise ArgumentError, "Unknown tokenizer: #{tokenizer_spec}"
        end
      end

      def validate_parameters!
        raise ArgumentError, "max_tokens must be positive" if max_tokens <= 0
        raise ArgumentError, "overlap_tokens cannot be negative" if overlap_tokens < 0
        raise ArgumentError, "overlap_tokens must be less than max_tokens" if overlap_tokens >= max_tokens
        raise ArgumentError, "min_tokens cannot be negative" if min_tokens < 0
      end
    end
  end
end
