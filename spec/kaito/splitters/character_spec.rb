# frozen_string_literal: true

RSpec.describe Kaito::Splitters::Character do
  let(:splitter) { described_class.new(max_tokens: 20, tokenizer: :character) }

  describe "#split" do
    it "splits text into chunks" do
      text = "a" * 50
      chunks = splitter.split(text)

      expect(chunks).to be_an(Array)
      expect(chunks.length).to be > 1
      expect(chunks).to all(be_a(Kaito::Chunk))
    end

    it "respects max_tokens limit" do
      text = "a" * 100
      chunks = splitter.split(text)

      chunks.each do |chunk|
        expect(chunk.token_count).to be <= 20
      end
    end

    it "handles overlap" do
      splitter = described_class.new(max_tokens: 20, overlap_tokens: 5, tokenizer: :character)
      text = "a" * 50
      chunks = splitter.split(text)

      expect(chunks.length).to be > 1
    end

    it "returns empty array for empty text" do
      expect(splitter.split("")).to eq([])
      expect(splitter.split(nil)).to eq([])
    end

    it "handles text shorter than max_tokens" do
      text = "short"
      chunks = splitter.split(text)

      expect(chunks.length).to eq(1)
      expect(chunks.first.text).to eq(text)
    end

    it "adds metadata to chunks" do
      text = "a" * 50
      chunks = splitter.split(text)

      chunks.each_with_index do |chunk, idx|
        expect(chunk.index).to eq(idx)
        expect(chunk.metadata[:start_offset]).to be_a(Integer)
      end
    end
  end
end
