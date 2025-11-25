# frozen_string_literal: true

RSpec.describe Kaito::Tokenizers::Character do
  let(:tokenizer) { described_class.new }

  describe '#count' do
    it 'counts characters in text' do
      expect(tokenizer.count('hello')).to eq(5)
    end

    it 'returns 0 for empty string' do
      expect(tokenizer.count('')).to eq(0)
    end

    it 'returns 0 for nil' do
      expect(tokenizer.count(nil)).to eq(0)
    end

    it 'counts unicode characters correctly' do
      expect(tokenizer.count('hello 世界')).to eq(8)
    end
  end

  describe '#encode' do
    it 'encodes text to character codes' do
      result = tokenizer.encode('abc')
      expect(result).to eq([97, 98, 99])
    end

    it 'returns empty array for empty string' do
      expect(tokenizer.encode('')).to eq([])
    end
  end

  describe '#decode' do
    it 'decodes character codes to text' do
      result = tokenizer.decode([97, 98, 99])
      expect(result).to eq('abc')
    end

    it 'returns empty string for empty array' do
      expect(tokenizer.decode([])).to eq('')
    end
  end

  describe '#truncate' do
    it 'truncates text to max tokens' do
      result = tokenizer.truncate('hello world', max_tokens: 5)
      expect(result).to eq('hello')
    end

    it 'returns original text if within limit' do
      result = tokenizer.truncate('hi', max_tokens: 5)
      expect(result).to eq('hi')
    end
  end
end
