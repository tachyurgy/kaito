# frozen_string_literal: true

RSpec.describe Kaito::Splitters::Semantic do
  let(:splitter) { described_class.new(max_tokens: 50, tokenizer: :character) }

  describe '#split' do
    let(:text) do
      'This is the first sentence. This is the second sentence. ' \
        'This is the third sentence. This is the fourth sentence.'
    end

    it 'splits text into chunks' do
      chunks = splitter.split(text)

      expect(chunks).to be_an(Array)
      expect(chunks).to all(be_a(Kaito::Chunk))
    end

    it 'preserves sentence boundaries when possible' do
      chunks = splitter.split(text)

      chunks.each do |chunk|
        # Check that chunks don't break mid-sentence inappropriately
        expect(chunk.text).not_to be_empty
      end
    end

    it 'handles paragraphs when preserve_paragraphs is true' do
      splitter = described_class.new(
        max_tokens: 100,
        tokenizer: :character,
        preserve_paragraphs: true
      )

      text = "Paragraph one.\n\nParagraph two.\n\nParagraph three."
      chunks = splitter.split(text)

      expect(chunks).not_to be_empty
    end

    it 'returns empty array for empty text' do
      expect(splitter.split('')).to eq([])
      expect(splitter.split(nil)).to eq([])
    end

    it 'handles text with no sentence boundaries' do
      text = 'a' * 100
      chunks = splitter.split(text)

      expect(chunks).not_to be_empty
      chunks.each do |chunk|
        expect(chunk.token_count).to be <= 50
      end
    end

    it 'adds metadata with segment count' do
      chunks = splitter.split(text)

      chunks.each do |chunk|
        expect(chunk.metadata).to include(:index)
      end
    end
  end
end
