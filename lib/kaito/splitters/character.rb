# frozen_string_literal: true

module Kaito
  module Splitters
    # Simple character-based text splitter
    # Splits text by character/token count without regard for semantic boundaries
    class Character < Base
      # Split text into chunks based on token count
      #
      # @param text [String] the text to split
      # @return [Array<Chunk>] array of text chunks
      def split(text)
        return [] if text.nil? || text.empty?

        chunks = []
        current_pos = 0

        while current_pos < text.length
          # Find the end position for this chunk
          chunk_text = extract_chunk(text, current_pos)
          break if chunk_text.empty?

          chunks << Chunk.new(
            chunk_text,
            metadata: { index: chunks.length, start_offset: current_pos },
            token_count: tokenizer.count(chunk_text)
          )

          # Move position forward, accounting for overlap
          advance = chunk_text.length
          if overlap_tokens > 0 && current_pos + advance < text.length
            # Calculate how much to step back for overlap
            overlap_chars = calculate_overlap_chars(chunk_text)
            current_pos += advance - overlap_chars
          else
            current_pos += advance
          end
        end

        chunks
      end

      private

      def extract_chunk(text, start_pos)
        remaining = text[start_pos..-1]
        return "" if remaining.empty?

        # Binary search for the right length
        min_len = 1
        max_len = remaining.length
        best_length = min_len

        while min_len <= max_len
          mid = (min_len + max_len) / 2
          candidate = remaining[0...mid]
          token_count = tokenizer.count(candidate)

          if token_count <= max_tokens
            best_length = mid
            min_len = mid + 1
          else
            max_len = mid - 1
          end
        end

        remaining[0...best_length]
      end

      def calculate_overlap_chars(text)
        return 0 if overlap_tokens == 0 || text.empty?

        # Binary search for character length that gives us overlap_tokens
        min_len = 0
        max_len = text.length
        best_length = 0

        while min_len <= max_len
          mid = (min_len + max_len) / 2
          suffix = text[-mid..-1] || ""
          token_count = tokenizer.count(suffix)

          if token_count <= overlap_tokens
            best_length = mid
            min_len = mid + 1
          else
            max_len = mid - 1
          end
        end

        best_length
      end
    end
  end
end
