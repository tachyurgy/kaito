# frozen_string_literal: true

RSpec.describe Kaito::Chunk do
  let(:text) { 'This is a test chunk' }
  let(:metadata) { { index: 0, source_file: 'test.txt' } }
  let(:chunk) { described_class.new(text, metadata: metadata, token_count: 5) }

  describe '#initialize' do
    it 'creates a chunk with text' do
      expect(chunk.text).to eq(text)
    end

    it 'creates a chunk with metadata' do
      expect(chunk.metadata).to eq(metadata)
    end

    it 'creates a chunk with token count' do
      expect(chunk.token_count).to eq(5)
    end

    it 'falls back to character count if no token count provided' do
      chunk = described_class.new(text)
      expect(chunk.token_count).to eq(text.length)
    end

    it 'freezes metadata' do
      expect(chunk.metadata).to be_frozen
    end
  end

  describe 'metadata accessors' do
    it 'returns index' do
      expect(chunk.index).to eq(0)
    end

    it 'returns source_file' do
      expect(chunk.source_file).to eq('test.txt')
    end

    it 'returns nil for missing metadata' do
      chunk = described_class.new(text)
      expect(chunk.index).to be_nil
    end
  end

  describe '#to_h' do
    it 'returns hash representation' do
      hash = chunk.to_h
      expect(hash).to include(
        text: text,
        token_count: 5,
        metadata: metadata
      )
    end
  end

  describe '#==' do
    it 'compares chunks by text and metadata' do
      chunk1 = described_class.new(text, metadata: metadata)
      chunk2 = described_class.new(text, metadata: metadata)
      expect(chunk1).to eq(chunk2)
    end

    it 'returns false for different text' do
      chunk1 = described_class.new('text1')
      chunk2 = described_class.new('text2')
      expect(chunk1).not_to eq(chunk2)
    end
  end

  describe '#to_s' do
    it 'returns string representation' do
      str = chunk.to_s
      expect(str).to include('5 tokens')
      expect(str).to include('index: 0')
    end
  end
end
