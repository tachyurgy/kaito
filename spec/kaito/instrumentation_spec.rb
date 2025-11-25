# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Kaito::Instrumentation do
  # Clear subscriptions before each test
  before do
    described_class.clear_subscriptions
  end

  after do
    described_class.clear_subscriptions
  end

  describe '.subscribe' do
    it 'subscribes to all events when no pattern provided' do
      events = []
      described_class.subscribe { |event| events << event }

      described_class.instrument('test.kaito') { 'result' }

      expect(events.size).to eq(1)
      expect(events.first.name).to eq('test.kaito')
    end

    it 'subscribes to specific event name' do
      events = []
      described_class.subscribe('test.kaito') { |event| events << event }

      described_class.instrument('test.kaito') { 'result' }
      described_class.instrument('other.kaito') { 'result' }

      expect(events.size).to eq(1)
      expect(events.first.name).to eq('test.kaito')
    end

    it 'subscribes with regex pattern' do
      events = []
      described_class.subscribe(/\.kaito$/) { |event| events << event }

      described_class.instrument('text_split.kaito') { 'result' }
      described_class.instrument('tokenization.kaito') { 'result' }
      described_class.instrument('other.event') { 'result' }

      expect(events.size).to eq(2)
      expect(events.map(&:name)).to contain_exactly('text_split.kaito', 'tokenization.kaito')
    end

    it 'requires a block' do
      expect { described_class.subscribe }.to raise_error(ArgumentError, /block required/i)
    end

    it 'returns a subscriber object' do
      subscriber = described_class.subscribe { |_event| }
      expect(subscriber).not_to be_nil
      expect(subscriber).to be_a(Hash)
    end
  end

  describe '.unsubscribe' do
    it 'removes a subscription' do
      events = []
      subscriber = described_class.subscribe { |event| events << event }

      described_class.instrument('test.kaito') { 'result' }
      expect(events.size).to eq(1)

      described_class.unsubscribe(subscriber)
      described_class.instrument('test.kaito') { 'result' }
      expect(events.size).to eq(1) # No new events
    end
  end

  describe '.clear_subscriptions' do
    it 'removes all subscriptions' do
      events = []
      described_class.subscribe { |event| events << event }
      described_class.subscribe { |event| events << event }

      described_class.clear_subscriptions
      described_class.instrument('test.kaito') { 'result' }

      expect(events).to be_empty
    end
  end

  describe '.instrument' do
    it 'executes the block and returns result' do
      result = described_class.instrument('test.kaito') { 42 }
      expect(result).to eq(42)
    end

    it 'provides event to subscribers' do
      event = nil
      described_class.subscribe { |e| event = e }

      described_class.instrument('test.kaito', foo: 'bar') { 'result' }

      expect(event).not_to be_nil
      expect(event.name).to eq('test.kaito')
      expect(event.payload[:foo]).to eq('bar')
    end

    it 'measures duration of block execution' do
      event = nil
      described_class.subscribe { |e| event = e }

      described_class.instrument('test.kaito') do
        sleep 0.01
        'result'
      end

      expect(event.duration).to be > 0
      expect(event.duration_seconds).to be > 0
    end

    it 'publishes event even if block raises error' do
      event = nil
      described_class.subscribe { |e| event = e }

      expect do
        described_class.instrument('test.kaito') { raise 'error' }
      end.to raise_error('error')

      expect(event).not_to be_nil
      expect(event.name).to eq('test.kaito')
    end

    it 'does not call instrumentation if no subscribers' do
      # Should not slow down operations when no subscribers
      start_time = Time.now
      result = described_class.instrument('test.kaito') { 42 }
      duration = Time.now - start_time

      expect(result).to eq(42)
      expect(duration).to be < 0.001 # Should be very fast
    end
  end

  describe '.instrument_split' do
    it 'instruments text splitting with metadata' do
      event = nil
      described_class.subscribe('text_split.kaito') { |e| event = e }

      chunks = [
        Kaito::Chunk.new('text1', token_count: 10),
        Kaito::Chunk.new('text2', token_count: 15)
      ]

      result = described_class.instrument_split(
        strategy: :semantic,
        text_length: 100,
        max_tokens: 50,
        overlap_tokens: 5
      ) { chunks }

      expect(result).to eq(chunks)
      expect(event).not_to be_nil
      expect(event.payload[:strategy]).to eq(:semantic)
      expect(event.payload[:text_length]).to eq(100)
      expect(event.payload[:max_tokens]).to eq(50)
      expect(event.payload[:overlap_tokens]).to eq(5)
      expect(event.payload[:chunks_created]).to eq(2)
      expect(event.payload[:tokens_processed]).to eq(25)
    end
  end

  describe '.instrument_tokenization' do
    it 'instruments tokenization with metadata' do
      event = nil
      described_class.subscribe('tokenization.kaito') { |e| event = e }

      result = described_class.instrument_tokenization(
        tokenizer: :gpt4,
        text_length: 100
      ) { 42 }

      expect(result).to eq(42)
      expect(event).not_to be_nil
      expect(event.payload[:tokenizer]).to eq(:gpt4)
      expect(event.payload[:text_length]).to eq(100)
      expect(event.payload[:token_count]).to eq(42)
    end
  end

  describe '.instrument_streaming' do
    it 'instruments file streaming with metadata' do
      event = nil
      described_class.subscribe('file_streaming.kaito') { |e| event = e }

      result = described_class.instrument_streaming(
        file_path: '/path/to/file.txt',
        file_size: 1000,
        strategy: :semantic
      ) do |chunk_callback|
        3.times { chunk_callback.call('chunk') }
        'result'
      end

      expect(result).to eq('result')
      expect(event).not_to be_nil
      expect(event.payload[:file_path]).to eq('/path/to/file.txt')
      expect(event.payload[:file_size]).to eq(1000)
      expect(event.payload[:strategy]).to eq(:semantic)
      expect(event.payload[:chunks_streamed]).to eq(3)
    end
  end

  describe '.enabled?' do
    it 'returns true when there are subscribers' do
      described_class.subscribe { |_event| }
      expect(described_class).to be_enabled
    end

    it 'returns false when there are no subscribers' do
      expect(described_class).not_to be_enabled
    end
  end

  describe '.subscriber_count' do
    it 'returns number of active subscribers' do
      expect(described_class.subscriber_count).to eq(0)

      described_class.subscribe { |_event| }
      expect(described_class.subscriber_count).to eq(1)

      described_class.subscribe { |_event| }
      expect(described_class.subscriber_count).to eq(2)
    end
  end

  describe 'Event' do
    describe '#duration' do
      it 'calculates duration in milliseconds' do
        start_time = Time.now
        end_time = start_time + 0.5 # 0.5 seconds later

        event = described_class::Event.new('test', {}, start_time, end_time)
        expect(event.duration).to eq(500.0)
      end

      it 'returns 0 if times not provided' do
        event = described_class::Event.new('test', {}, nil, nil)
        expect(event.duration).to eq(0.0)
      end
    end

    describe '#duration_seconds' do
      it 'calculates duration in seconds' do
        start_time = Time.now
        end_time = start_time + 1.5 # 1.5 seconds later

        event = described_class::Event.new('test', {}, start_time, end_time)
        expect(event.duration_seconds).to eq(1.5)
      end
    end

    describe '#payload' do
      it 'is frozen' do
        event = described_class::Event.new('test', { foo: 'bar' }, Time.now, Time.now)
        expect(event.payload).to be_frozen
      end
    end
  end

  describe 'error handling in subscribers' do
    it 'continues executing other subscribers if one fails' do
      events = []

      described_class.subscribe do |_event|
        raise 'Subscriber error'
      end

      described_class.subscribe do |event|
        events << event
      end

      expect do
        described_class.instrument('test.kaito') { 'result' }
      end.not_to raise_error

      expect(events.size).to eq(1)
    end

    it 'warns about subscriber errors' do
      described_class.subscribe { |_event| raise 'Error' }

      expect do
        described_class.instrument('test.kaito') { 'result' }
      end.to output(/Error in instrumentation subscriber/).to_stderr
    end
  end

  describe 'multiple subscribers' do
    it 'notifies all matching subscribers' do
      events1 = []
      events2 = []

      described_class.subscribe { |event| events1 << event }
      described_class.subscribe { |event| events2 << event }

      described_class.instrument('test.kaito') { 'result' }

      expect(events1.size).to eq(1)
      expect(events2.size).to eq(1)
    end

    it 'only notifies subscribers matching pattern' do
      all_events = []
      kaito_events = []
      split_events = []

      described_class.subscribe { |event| all_events << event }
      described_class.subscribe(/\.kaito$/) { |event| kaito_events << event }
      described_class.subscribe('text_split.kaito') { |event| split_events << event }

      described_class.instrument('text_split.kaito') { 'result' }
      described_class.instrument('tokenization.kaito') { 'result' }
      described_class.instrument('other.event') { 'result' }

      expect(all_events.size).to eq(3)
      expect(kaito_events.size).to eq(2)
      expect(split_events.size).to eq(1)
    end
  end
end
