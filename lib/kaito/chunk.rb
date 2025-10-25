# frozen_string_literal: true

module Kaito
  # Represents a chunk of text with metadata
  #
  # @attr_reader text [String] the chunk text
  # @attr_reader metadata [Hash] metadata about the chunk
  # @attr_reader token_count [Integer] number of tokens in the chunk
  class Chunk
    attr_reader :text, :metadata, :token_count

    # Create a new chunk
    #
    # @param text [String] the chunk text
    # @param metadata [Hash] metadata for the chunk
    # @option metadata [Integer] :index the chunk index in the sequence
    # @option metadata [Integer] :start_offset byte offset where chunk starts in source
    # @option metadata [Integer] :end_offset byte offset where chunk ends in source
    # @option metadata [String] :source_file path to source file if applicable
    # @option metadata [Hash] :structure structural metadata (headers, sections, etc.)
    # @param token_count [Integer] number of tokens (will be calculated if not provided)
    def initialize(text, metadata: {}, token_count: nil)
      @text = text
      @metadata = metadata.dup.freeze
      @token_count = token_count || text.length # Fallback to character count
    end

    # Get the chunk index
    # @return [Integer, nil]
    def index
      metadata[:index]
    end

    # Get the source file
    # @return [String, nil]
    def source_file
      metadata[:source_file]
    end

    # Get the start offset
    # @return [Integer, nil]
    def start_offset
      metadata[:start_offset]
    end

    # Get the end offset
    # @return [Integer, nil]
    def end_offset
      metadata[:end_offset]
    end

    # Get structural metadata
    # @return [Hash, nil]
    def structure
      metadata[:structure]
    end

    # Convert chunk to hash
    # @return [Hash]
    def to_h
      {
        text: text,
        token_count: token_count,
        metadata: metadata
      }
    end

    # Convert chunk to JSON-compatible hash
    # @return [Hash]
    def as_json
      to_h
    end

    # String representation
    # @return [String]
    def to_s
      "Chunk(#{token_count} tokens, index: #{index})"
    end

    # Detailed inspection
    # @return [String]
    def inspect
      "#<Kaito::Chunk text=#{text[0..50].inspect}... tokens=#{token_count} metadata=#{metadata.inspect}>"
    end

    # Check if two chunks are equal
    # @param other [Chunk]
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(Chunk)

      text == other.text && metadata == other.metadata
    end

    alias eql? ==

    # Hash code for chunk
    # @return [Integer]
    def hash
      [text, metadata].hash
    end
  end
end
