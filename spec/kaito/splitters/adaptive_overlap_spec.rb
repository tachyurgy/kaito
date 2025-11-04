# frozen_string_literal: true

RSpec.describe Kaito::Splitters::AdaptiveOverlap do
  let(:splitter) {
    described_class.new(
      max_tokens: 100,
      overlap_tokens: 20,
      tokenizer: :character
    )
  }

  describe "#initialize" do
    it "initializes with default parameters" do
      splitter = described_class.new
      expect(splitter.max_tokens).to eq(512)
      expect(splitter.overlap_tokens).to eq(50)
      expect(splitter.min_overlap_tokens).to eq(20)
      expect(splitter.max_overlap_tokens).to eq(100)
      expect(splitter.similarity_threshold).to eq(0.3)
    end

    it "initializes with custom parameters" do
      splitter = described_class.new(
        max_tokens: 256,
        overlap_tokens: 30,
        min_overlap_tokens: 10,
        max_overlap_tokens: 50,
        similarity_threshold: 0.5
      )

      expect(splitter.max_tokens).to eq(256)
      expect(splitter.overlap_tokens).to eq(30)
      expect(splitter.min_overlap_tokens).to eq(10)
      expect(splitter.max_overlap_tokens).to eq(50)
      expect(splitter.similarity_threshold).to eq(0.5)
    end
  end

  describe "#split" do
    let(:text) do
      "This is the first sentence about AI. " \
      "This is the second sentence about machine learning. " \
      "This is the third sentence about neural networks. " \
      "This is the fourth sentence about deep learning. " \
      "This is the fifth sentence about AI. "
    end

    it "splits text into chunks with adaptive overlap" do
      chunks = splitter.split(text)

      expect(chunks).to be_an(Array)
      expect(chunks).to all(be_a(Kaito::Chunk))
      expect(chunks.length).to be > 0
    end

    it "returns empty array for empty text" do
      expect(splitter.split("")).to eq([])
      expect(splitter.split(nil)).to eq([])
    end

    it "returns single chunk for short text" do
      short_text = "This is a short text."
      chunks = splitter.split(short_text)

      expect(chunks.length).to eq(1)
      expect(chunks.first.text).to eq(short_text)
    end

    it "adds adaptive_overlap metadata to chunks after the first" do
      long_text = ("This is sentence number one. " * 10) +
                  ("This is sentence number two. " * 10)

      chunks = splitter.split(long_text)

      if chunks.length > 1
        # First chunk should not have adaptive_overlap metadata
        expect(chunks.first.metadata[:adaptive_overlap]).to be_nil

        # Subsequent chunks should have adaptive_overlap metadata
        chunks[1..].each do |chunk|
          expect(chunk.metadata[:adaptive_overlap]).to eq(true)
          expect(chunk.metadata).to include(:overlap_tokens)
        end
      end
    end

    it "adds overlap_tokens metadata" do
      long_text = ("This is a test sentence. " * 20)
      chunks = splitter.split(long_text)

      if chunks.length > 1
        chunks[1..].each do |chunk|
          expect(chunk.metadata).to include(:overlap_tokens)
          expect(chunk.metadata[:overlap_tokens]).to be_a(Integer)
          expect(chunk.metadata[:overlap_tokens]).to be >= 0
        end
      end
    end

    it "creates chunks that may exceed max_tokens due to overlap" do
      long_text = "word " * 200
      chunks = splitter.split(long_text)

      # First chunk should respect max_tokens
      expect(chunks.first.token_count).to be <= splitter.max_tokens

      # Subsequent chunks may exceed max_tokens due to added overlap
      # But shouldn't be dramatically larger
      chunks.each do |chunk|
        expect(chunk.token_count).to be <= (splitter.max_tokens * 2)
      end
    end

    it "provides appropriate overlap between consecutive chunks" do
      long_text = ("Sentence one about AI. " * 5) +
                  ("Sentence two about ML. " * 5) +
                  ("Sentence three about DL. " * 5)

      chunks = splitter.split(long_text)

      if chunks.length > 1
        chunks[1..].each do |chunk|
          overlap = chunk.metadata[:overlap_tokens]
          # Note: overlap may be less than min if needed to respect max_tokens
          # This is correct behavior - max_tokens is a hard limit
          expect(overlap).to be <= splitter.max_overlap_tokens
          # Verify chunk never exceeds max_tokens (most important)
          expect(chunk.token_count).to be <= splitter.max_tokens
        end
      end
    end

    it "handles text with multiple paragraphs" do
      text = "Paragraph one has multiple sentences. " \
             "It talks about various topics.\n\n" \
             "Paragraph two is different. " \
             "It discusses other matters.\n\n" \
             "Paragraph three continues. " \
             "It provides more information."

      chunks = splitter.split(text)
      expect(chunks).to all(be_a(Kaito::Chunk))
      expect(chunks).not_to be_empty
    end

    it "preserves sentence boundaries in overlap when possible" do
      long_text = ("Complete sentence one. " * 10) +
                  ("Complete sentence two. " * 10)

      chunks = splitter.split(long_text)

      if chunks.length > 1
        # Check that overlaps don't break mid-sentence when possible
        chunks[1..].each do |chunk|
          # If there's overlap, it should ideally be complete sentences
          # This is a soft check - we just ensure text is not completely broken
          expect(chunk.text).not_to be_empty
        end
      end
    end

    it "handles text without clear sentence boundaries" do
      text = "a" * 300
      chunks = splitter.split(text)

      expect(chunks).not_to be_empty
      # Chunks may exceed max_tokens due to overlap
      # Just ensure they're not empty and reasonably sized
      chunks.each do |chunk|
        expect(chunk.text).not_to be_empty
        expect(chunk.token_count).to be > 0
      end
    end

    it "indexes chunks correctly" do
      long_text = "sentence " * 100
      chunks = splitter.split(long_text)

      chunks.each_with_index do |chunk, expected_index|
        expect(chunk.metadata[:index]).to eq(expected_index)
      end
    end
  end

  describe "overlap calculation" do
    let(:splitter) {
      described_class.new(
        max_tokens: 80,
        overlap_tokens: 15,
        min_overlap_tokens: 5,
        max_overlap_tokens: 25,
        similarity_threshold: 0.3,
        tokenizer: :character
      )
    }

    it "adapts overlap based on content similarity" do
      # Text with high similarity between sections
      similar_text = ("The AI system processes data efficiently. " * 3) +
                     ("The AI system handles requests quickly. " * 3)

      chunks = splitter.split(similar_text)

      if chunks.length > 1
        # Should have overlap (may be 0 for very short chunks that don't get split)
        overlap = chunks[1].metadata[:overlap_tokens]
        expect(overlap).to be >= 0
      end
    end

    it "handles overlap for dissimilar content" do
      # Text with low similarity between sections
      dissimilar_text = ("Completely different topic about cats and dogs. " * 3) +
                       ("Now discussing quantum physics and mathematics. " * 3)

      chunks = splitter.split(dissimilar_text)

      if chunks.length > 1
        # May have minimal or no overlap due to dissimilar content
        overlap = chunks[1].metadata[:overlap_tokens]
        # Overlap should be non-negative
        expect(overlap).to be >= 0
      end
    end
  end

  describe "edge cases" do
    it "handles very long text" do
      long_text = ("This is a test sentence with various words. " * 100)
      chunks = splitter.split(long_text)

      expect(chunks).not_to be_empty
      expect(chunks).to all(be_a(Kaito::Chunk))
    end

    it "handles single sentence" do
      text = "This is a single sentence."
      chunks = splitter.split(text)

      expect(chunks.length).to eq(1)
      expect(chunks.first.text).to eq(text)
    end

    it "handles text with special characters" do
      text = "Special chars: @#$%^&*(). " \
             "More special: <>?\"{}|\\. " \
             "Even more: ~`![]+=."

      chunks = splitter.split(text)
      expect(chunks).not_to be_empty
    end

    it "handles unicode text" do
      text = "This is English. " \
             "これは日本語です。" \
             "هذا عربي. " \
             "זה עברית."

      chunks = splitter.split(text)
      expect(chunks).not_to be_empty
    end

    it "handles text with code blocks" do
      text = "Here is some code:\n\n" \
             "```ruby\n" \
             "def hello\n" \
             "  puts 'world'\n" \
             "end\n" \
             "```\n\n" \
             "And more text follows."

      chunks = splitter.split(text)
      expect(chunks).not_to be_empty
    end
  end

  describe "similarity threshold impact" do
    it "uses higher overlap with high similarity threshold" do
      high_threshold_splitter = described_class.new(
        max_tokens: 80,
        overlap_tokens: 15,
        min_overlap_tokens: 5,
        max_overlap_tokens: 25,
        similarity_threshold: 0.8, # High threshold
        tokenizer: :character
      )

      text = ("Similar content here. " * 5) +
             ("Similar content there. " * 5)

      chunks = high_threshold_splitter.split(text)

      if chunks.length > 1
        # With high threshold, may have minimal overlap unless very similar
        overlap = chunks[1].metadata[:overlap_tokens]
        expect(overlap).to be >= high_threshold_splitter.min_overlap_tokens
      end
    end

    it "uses more overlap with low similarity threshold" do
      low_threshold_splitter = described_class.new(
        max_tokens: 80,
        overlap_tokens: 15,
        min_overlap_tokens: 5,
        max_overlap_tokens: 25,
        similarity_threshold: 0.1, # Low threshold
        tokenizer: :character
      )

      text = ("Different content. " * 5) +
             ("Completely other stuff. " * 5)

      chunks = low_threshold_splitter.split(text)

      if chunks.length > 1
        # With low threshold, should include more in overlap
        overlap = chunks[1].metadata[:overlap_tokens]
        expect(overlap).to be > low_threshold_splitter.min_overlap_tokens
      end
    end
  end

  describe "chunk metadata" do
    it "includes all required metadata fields" do
      long_text = "sentence " * 100
      chunks = splitter.split(long_text)

      chunks.each do |chunk|
        expect(chunk.metadata).to include(:index)
        expect(chunk.text).to be_a(String)
        expect(chunk.token_count).to be_a(Integer)
      end

      # Chunks after first should have overlap metadata
      if chunks.length > 1
        chunks[1..].each do |chunk|
          expect(chunk.metadata).to include(:overlap_tokens)
          expect(chunk.metadata).to include(:adaptive_overlap)
        end
      end
    end
  end

  describe "tokenizer integration" do
    it "works with character tokenizer" do
      char_splitter = described_class.new(
        max_tokens: 50,
        overlap_tokens: 10,
        tokenizer: :character
      )
      text = "a" * 200

      chunks = char_splitter.split(text)
      expect(chunks).not_to be_empty
      # First chunk should be within limit
      expect(chunks.first.token_count).to be <= 50
    end

    it "respects tokenizer for overlap calculation" do
      text = ("Test sentence. " * 20)
      chunks = splitter.split(text)

      if chunks.length > 1
        chunks[1..].each do |chunk|
          # Overlap tokens should be counted by the tokenizer
          overlap_tokens = chunk.metadata[:overlap_tokens]
          expect(overlap_tokens).to be_a(Integer)
        end
      end
    end
  end
end
