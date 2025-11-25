# frozen_string_literal: true

RSpec.describe Kaito do
  it 'has a version number' do
    expect(Kaito::VERSION).not_to be_nil
    expect(Kaito::VERSION).to match(/\d+\.\d+\.\d+/)
  end

  describe '.configure' do
    it 'yields configuration' do
      expect { |b| Kaito.configure(&b) }.to yield_with_args(Kaito::Configuration)
    end

    it 'allows setting configuration options' do
      Kaito.configure do |config|
        config.default_max_tokens = 1000
        config.default_tokenizer = :gpt35_turbo
      end

      expect(Kaito.configuration.default_max_tokens).to eq(1000)
      expect(Kaito.configuration.default_tokenizer).to eq(:gpt35_turbo)
    end
  end

  describe '.split' do
    let(:text) do
      'This is a test. This is only a test. In the event of a real emergency, you would be instructed where to tune.'
    end

    it 'splits text with default options' do
      chunks = Kaito.split(text)
      expect(chunks).to be_an(Array)
      expect(chunks).to all(be_a(Kaito::Chunk))
    end

    it 'accepts strategy parameter' do
      expect { Kaito.split(text, strategy: :character) }.not_to raise_error
      expect { Kaito.split(text, strategy: :semantic) }.not_to raise_error
      expect { Kaito.split(text, strategy: :recursive) }.not_to raise_error
    end

    it 'accepts max_tokens parameter' do
      chunks = Kaito.split(text, max_tokens: 20, tokenizer: :character)
      expect(chunks.all? { |c| c.token_count <= 20 }).to be true
    end

    it 'raises error for unknown strategy' do
      expect { Kaito.split(text, strategy: :unknown) }.to raise_error(ArgumentError, /Unknown strategy/)
    end
  end

  describe '.count_tokens' do
    it 'counts tokens using specified tokenizer' do
      text = 'Hello world'
      count = Kaito.count_tokens(text, tokenizer: :character)
      expect(count).to eq(text.length)
    end
  end
end
