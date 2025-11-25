# frozen_string_literal: true

RSpec.describe Kaito::Tokenizers::Tiktoken do
  # Skip these tests if tiktoken_ruby is not available
  before(:all) do
    skip 'tiktoken_ruby gem is not installed. Install with: gem install tiktoken_ruby' unless defined?(Tiktoken)
  end

  describe '#initialize' do
    it 'initializes with default gpt4 model' do
      tokenizer = described_class.new
      expect(tokenizer.encoding_name).to eq('cl100k_base')
    end

    it 'initializes with gpt35_turbo model' do
      tokenizer = described_class.new(model: :gpt35_turbo)
      expect(tokenizer.encoding_name).to eq('cl100k_base')
    end

    it 'initializes with custom encoding name' do
      tokenizer = described_class.new(model: 'cl100k_base')
      expect(tokenizer.encoding_name).to eq('cl100k_base')
    end


    it 'initializes with legacy model' do
      tokenizer = described_class.new(model: :text_davinci_003)
      expect(tokenizer.encoding_name).to eq('p50k_base')
    end

    it 'raises error when tiktoken is not available', skip: defined?(Tiktoken) do
      expect do
        described_class.new
      end.to raise_error(Kaito::TokenizationError, /tiktoken_ruby gem is not available/)
    end
  end

  describe '#count' do
    let(:tokenizer) { described_class.new }

    it 'counts tokens in simple text' do
      count = tokenizer.count('hello world')
      expect(count).to be > 0
      expect(count).to be < 10 # Should be around 2-3 tokens
    end

    it 'returns 0 for empty string' do
      expect(tokenizer.count('')).to eq(0)
    end

    it 'returns 0 for nil' do
      expect(tokenizer.count(nil)).to eq(0)
    end

    it 'counts tokens for longer text' do
      text = 'The quick brown fox jumps over the lazy dog'
      count = tokenizer.count(text)
      expect(count).to be > 5
      expect(count).to be < 20
    end

    it 'handles unicode characters' do
      text = 'Hello 世界'
      count = tokenizer.count(text)
      expect(count).to be > 0
    end

    it 'handles special characters' do
      text = "Hello! How are you? I'm fine, thanks."
      count = tokenizer.count(text)
      expect(count).to be > 0
    end

    it 'handles code snippets' do
      code = "function hello() { return 'world'; }"
      count = tokenizer.count(code)
      expect(count).to be > 0
    end

    it 'caches token counts when caching is enabled' do
      # Enable caching
      original_config = Kaito.configuration.cache_tokenization
      Kaito.configuration.instance_variable_set(:@cache_tokenization, true)

      tokenizer = described_class.new
      text = 'test text for caching'

      # First call
      first_count = tokenizer.count(text)
      # Second call should hit cache
      second_count = tokenizer.count(text)

      expect(first_count).to eq(second_count)

      # Restore original config
      Kaito.configuration.instance_variable_set(:@cache_tokenization, original_config)
    end

    it 'raises TokenizationError on encoding failure' do
      tokenizer = described_class.new
      allow(tokenizer.encoder).to receive(:encode).and_raise(StandardError, 'Encoding failed')

      expect do
        tokenizer.count('test')
      end.to raise_error(Kaito::TokenizationError, /Failed to count tokens/)
    end
  end

  describe '#encode' do
    let(:tokenizer) { described_class.new }

    it 'encodes text to token IDs' do
      tokens = tokenizer.encode('hello')
      expect(tokens).to be_an(Array)
      expect(tokens).to all(be_an(Integer))
      expect(tokens.length).to be > 0
    end

    it 'returns empty array for empty string' do
      expect(tokenizer.encode('')).to eq([])
    end

    it 'returns empty array for nil' do
      expect(tokenizer.encode(nil)).to eq([])
    end

    it 'encodes complex text' do
      text = 'The AI revolution is here!'
      tokens = tokenizer.encode(text)
      expect(tokens).to be_an(Array)
      expect(tokens.length).to be > 0
    end

    it 'raises TokenizationError on encoding failure' do
      tokenizer = described_class.new
      allow(tokenizer.encoder).to receive(:encode).and_raise(StandardError, 'Encoding failed')

      expect do
        tokenizer.encode('test')
      end.to raise_error(Kaito::TokenizationError, /Failed to encode text/)
    end
  end

  describe '#decode' do
    let(:tokenizer) { described_class.new }

    it 'decodes tokens back to text' do
      text = 'hello world'
      tokens = tokenizer.encode(text)
      decoded = tokenizer.decode(tokens)
      expect(decoded).to eq(text)
    end

    it 'returns empty string for empty array' do
      expect(tokenizer.decode([])).to eq('')
    end

    it 'returns empty string for nil' do
      expect(tokenizer.decode(nil)).to eq('')
    end

    it 'handles round-trip encoding and decoding' do
      original = 'This is a test of tokenization!'
      tokens = tokenizer.encode(original)
      decoded = tokenizer.decode(tokens)
      expect(decoded).to eq(original)
    end

    it 'raises TokenizationError on decoding failure' do
      tokenizer = described_class.new
      allow(tokenizer.encoder).to receive(:decode).and_raise(StandardError, 'Decoding failed')

      expect do
        tokenizer.decode([123, 456])
      end.to raise_error(Kaito::TokenizationError, /Failed to decode tokens/)
    end
  end

  describe '#truncate' do
    let(:tokenizer) { described_class.new }

    it 'truncates text to max tokens' do
      long_text = 'This is a long text that should be truncated to fit within the maximum token limit'
      truncated = tokenizer.truncate(long_text, max_tokens: 5)

      expect(truncated).to be_a(String)
      expect(truncated.length).to be < long_text.length
      expect(tokenizer.count(truncated)).to be <= 5
    end

    it 'returns original text if within limit' do
      short_text = 'hello'
      result = tokenizer.truncate(short_text, max_tokens: 100)
      expect(result).to eq(short_text)
    end

    it 'handles edge case of max_tokens = 0' do
      text = 'some text'
      result = tokenizer.truncate(text, max_tokens: 0)
      expect(result).to be_empty
    end

    it 'handles edge case of max_tokens = 1' do
      text = 'hello world'
      result = tokenizer.truncate(text, max_tokens: 1)
      expect(tokenizer.count(result)).to be <= 1
    end

    it 'preserves text that exactly fits max_tokens' do
      text = 'hello'
      token_count = tokenizer.count(text)
      result = tokenizer.truncate(text, max_tokens: token_count)
      expect(result).to eq(text)
    end
  end

  describe '#clear_cache!' do
    it 'clears the tokenization cache' do
      # Enable caching
      original_config = Kaito.configuration.cache_tokenization
      Kaito.configuration.instance_variable_set(:@cache_tokenization, true)

      tokenizer = described_class.new
      text = 'test text'

      # Populate cache
      tokenizer.count(text)

      # Clear cache
      tokenizer.clear_cache!

      # Cache should be cleared (we can't directly test, but ensure method doesn't error)
      expect { tokenizer.clear_cache! }.not_to raise_error

      # Restore original config
      Kaito.configuration.instance_variable_set(:@cache_tokenization, original_config)
    end

    it 'handles clear_cache! when caching is disabled' do
      original_config = Kaito.configuration.cache_tokenization
      Kaito.configuration.instance_variable_set(:@cache_tokenization, false)

      tokenizer = described_class.new
      expect { tokenizer.clear_cache! }.not_to raise_error

      Kaito.configuration.instance_variable_set(:@cache_tokenization, original_config)
    end
  end

  describe 'model compatibility' do
    it 'works with different model encodings' do
      models = %i[gpt4 gpt35_turbo gpt4_turbo]

      models.each do |model|
        tokenizer = described_class.new(model: model)
        count = tokenizer.count('hello world')
        expect(count).to be > 0
      end
    end
  end

  describe 'edge cases' do
    let(:tokenizer) { described_class.new }

    it 'handles very long text' do
      long_text = 'hello ' * 1000
      count = tokenizer.count(long_text)
      expect(count).to be > 0
    end

    it 'handles text with newlines' do
      text = "line 1\nline 2\nline 3"
      count = tokenizer.count(text)
      expect(count).to be > 0
    end

    it 'handles text with tabs' do
      text = "column1\tcolumn2\tcolumn3"
      count = tokenizer.count(text)
      expect(count).to be > 0
    end

    it 'handles emoji' do
      text = 'Hello 👋 World 🌍'
      count = tokenizer.count(text)
      expect(count).to be > 0
    end

    it 'handles mixed scripts' do
      text = 'English, 日本語, العربية, עברית'
      count = tokenizer.count(text)
      expect(count).to be > 0
    end

    it 'handles special markdown syntax' do
      text = "# Heading\n\n**bold** and *italic*"
      count = tokenizer.count(text)
      expect(count).to be > 0
    end

    it 'handles JSON strings' do
      text = '{"key": "value", "number": 42}'
      count = tokenizer.count(text)
      expect(count).to be > 0
    end

    it 'handles HTML' do
      text = '<html><body><p>Hello World</p></body></html>'
      count = tokenizer.count(text)
      expect(count).to be > 0
    end
  end

  describe 'token accuracy' do
    let(:tokenizer) { described_class.new }

    it 'provides consistent token counts' do
      text = 'The quick brown fox jumps over the lazy dog'
      count1 = tokenizer.count(text)
      count2 = tokenizer.count(text)
      count3 = tokenizer.count(text)

      expect(count1).to eq(count2)
      expect(count2).to eq(count3)
    end

    it 'counts tokens correctly for known phrases' do
      # "hello" is typically 1 token in cl100k_base
      count = tokenizer.count('hello')
      expect(count).to be >= 1
      expect(count).to be <= 2
    end

    it 'maintains token count through encode/decode cycle' do
      text = 'This is a test of token accuracy'
      original_count = tokenizer.count(text)

      tokens = tokenizer.encode(text)
      expect(tokens.length).to eq(original_count)

      decoded = tokenizer.decode(tokens)
      decoded_count = tokenizer.count(decoded)
      expect(decoded_count).to eq(original_count)
    end
  end
end
