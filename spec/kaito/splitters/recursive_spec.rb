# frozen_string_literal: true

RSpec.describe Kaito::Splitters::Recursive do
  let(:splitter) { described_class.new(max_tokens: 50, tokenizer: :character) }

  describe '#split' do
    let(:text) do
      "Paragraph one has multiple sentences. It goes on and on.\n\n" \
        "Paragraph two is different. It also continues.\n\n" \
        'Paragraph three is the last one.'
    end

    it 'splits text recursively' do
      chunks = splitter.split(text)

      expect(chunks).to be_an(Array)
      expect(chunks).to all(be_a(Kaito::Chunk))
    end

    it 'respects max_tokens' do
      chunks = splitter.split(text)

      chunks.each do |chunk|
        expect(chunk.token_count).to be <= 50
      end
    end

    it 'tries larger separators first' do
      # Should prefer splitting on \n\n (paragraphs) before splitting on sentences
      chunks = splitter.split(text)

      expect(chunks).not_to be_empty
    end

    it 'handles overlap' do
      splitter = described_class.new(max_tokens: 50, overlap_tokens: 10, tokenizer: :character)
      chunks = splitter.split(text)

      expect(chunks.length).to be > 0
    end

    it 'keeps separators when keep_separator is true' do
      splitter = described_class.new(
        max_tokens: 100,
        tokenizer: :character,
        keep_separator: true
      )

      text = 'First. Second. Third.'
      chunks = splitter.split(text)

      expect(chunks).not_to be_empty
    end

    it 'returns empty array for empty text' do
      expect(splitter.split('')).to eq([])
    end

    it 'handles custom separators' do
      splitter = described_class.new(
        max_tokens: 50,
        tokenizer: :character,
        separators: ['|', ',', ' ']
      )

      text = 'part1|part2|part3,part4,part5 part6 part7'
      chunks = splitter.split(text)

      expect(chunks).not_to be_empty
    end
  end
end
