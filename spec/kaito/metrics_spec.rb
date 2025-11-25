# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Kaito::Metrics do
  describe '#initialize' do
    it 'creates a null metrics instance by default' do
      metrics = described_class.new
      expect(metrics.backend).to eq(:null)
      expect(metrics.enabled).to be true
    end

    it 'accepts custom backend' do
      client = double('statsd_client')
      metrics = described_class.new(backend: :statsd, client: client)
      expect(metrics.backend).to eq(:statsd)
    end

    it 'accepts custom namespace' do
      metrics = described_class.new(namespace: 'myapp')
      expect(metrics.namespace).to eq('myapp')
    end

    it 'can be initialized as disabled' do
      metrics = described_class.new(enabled: false)
      expect(metrics.enabled).to be false
    end

    it 'validates backend type' do
      expect do
        described_class.new(backend: :invalid)
      end.to raise_error(ArgumentError, /invalid backend/i)
    end
  end

  describe '#track_split' do
    let(:metrics) { described_class.new(backend: :null) }

    it 'tracks split operation metrics' do
      expect do
        metrics.track_split(
          strategy: :semantic,
          duration: 1.5,
          chunks: 5,
          tokens: 512
        )
      end.not_to raise_error
    end

    it 'does not track when disabled' do
      metrics.disable!
      expect(metrics.enabled).to be false

      # Should not raise any errors
      metrics.track_split(strategy: :semantic, duration: 1.0, chunks: 5)
    end
  end

  describe '#track_tokenization' do
    let(:metrics) { described_class.new }

    it 'tracks tokenization metrics' do
      expect do
        metrics.track_tokenization(
          tokenizer: :gpt4,
          duration: 0.5,
          tokens: 256
        )
      end.not_to raise_error
    end
  end

  describe '#track_streaming' do
    let(:metrics) { described_class.new }

    it 'tracks streaming metrics' do
      expect do
        metrics.track_streaming(
          strategy: :semantic,
          duration: 2.0,
          chunks: 10,
          file_size: 10_000
        )
      end.not_to raise_error
    end
  end

  describe '#track_error' do
    let(:metrics) { described_class.new }

    it 'tracks error metrics' do
      expect do
        metrics.track_error(
          operation: 'split',
          error_type: 'StandardError'
        )
      end.not_to raise_error
    end
  end

  describe '#increment' do
    context 'with null backend' do
      let(:metrics) { described_class.new }

      it 'does nothing' do
        expect { metrics.increment('test.counter') }.not_to raise_error
      end
    end

    context 'with statsd backend' do
      let(:client) { double('statsd_client') }
      let(:metrics) { described_class.new(backend: :statsd, client: client) }

      it 'calls increment on client' do
        expect(client).to receive(:increment).with('kaito.test.counter', 1, tags: [])
        metrics.increment('test.counter')
      end

      it 'includes namespace in metric name' do
        expect(client).to receive(:increment).with('kaito.test.counter', 1, tags: [])
        metrics.increment('test.counter')
      end

      it 'accepts custom value' do
        expect(client).to receive(:increment).with('kaito.test.counter', 5, tags: [])
        metrics.increment('test.counter', 5)
      end

      it 'formats tags correctly' do
        expect(client).to receive(:increment).with('kaito.test.counter', 1, tags: ['env:prod', 'region:us'])
        metrics.increment('test.counter', tags: { env: 'prod', region: 'us' })
      end
    end

    context 'with datadog backend' do
      let(:client) { double('datadog_client') }
      let(:metrics) { described_class.new(backend: :datadog, client: client) }

      it 'calls count on datadog client' do
        expect(client).to receive(:count).with('kaito.test.counter', 1, tags: [])
        metrics.increment('test.counter')
      end
    end

    context 'with custom backend' do
      let(:client) { double('custom_client') }
      let(:metrics) { described_class.new(backend: :custom, client: client) }

      it 'calls increment on custom client' do
        expect(client).to receive(:increment).with('kaito.test.counter', 1, tags: {})
        metrics.increment('test.counter')
      end
    end
  end

  describe '#timing' do
    context 'with statsd backend' do
      let(:client) { double('statsd_client') }
      let(:metrics) { described_class.new(backend: :statsd, client: client) }

      it 'calls timing on client with milliseconds' do
        expect(client).to receive(:timing).with('kaito.test.duration', 1500.0, tags: [])
        metrics.timing('test.duration', 1500.0)
      end

      it 'includes tags' do
        expect(client).to receive(:timing).with('kaito.test.duration', 1000.0, tags: ['operation:split'])
        metrics.timing('test.duration', 1000.0, tags: { operation: 'split' })
      end
    end
  end

  describe '#gauge' do
    context 'with statsd backend' do
      let(:client) { double('statsd_client') }
      let(:metrics) { described_class.new(backend: :statsd, client: client) }

      it 'calls gauge on client' do
        expect(client).to receive(:gauge).with('kaito.test.value', 42, tags: [])
        metrics.gauge('test.value', 42)
      end

      it 'does not call gauge when value is nil' do
        # This test would have caught the operator precedence bug
        expect(client).not_to receive(:gauge)
        metrics.gauge('test.value', nil)
      end

      it 'does not call gauge when metrics disabled' do
        metrics.disable!
        expect(client).not_to receive(:gauge)
        metrics.gauge('test.value', 42)
      end

      it 'does not call gauge when client is nil' do
        metrics_without_client = described_class.new(backend: :statsd, client: nil)
        expect { metrics_without_client.gauge('test.value', 42) }.not_to raise_error
      end
    end
  end

  describe '#measure' do
    context 'with null backend' do
      let(:metrics) { described_class.new }

      it 'executes block and returns result' do
        result = metrics.measure('test.duration') { 42 }
        expect(result).to eq(42)
      end
    end

    context 'with statsd backend' do
      let(:client) { double('statsd_client') }
      let(:metrics) { described_class.new(backend: :statsd, client: client) }

      it 'measures block execution time' do
        expect(client).to receive(:timing).with('kaito.test.duration', anything, tags: [])

        result = metrics.measure('test.duration') do
          sleep 0.01
          42
        end

        expect(result).to eq(42)
      end

      it 'includes tags in measurement' do
        expect(client).to receive(:timing).with('kaito.test.duration', anything, tags: ['op:split'])

        metrics.measure('test.duration', tags: { op: 'split' }) { 42 }
      end
    end
  end

  describe '#enable! and #disable!' do
    let(:client) { double('statsd_client', increment: nil) }
    let(:metrics) { described_class.new(backend: :statsd, client: client) }

    it 'can be dynamically enabled and disabled' do
      metrics.disable!
      expect(metrics.enabled).to be false

      # Should not call client when disabled
      metrics.increment('test.counter')

      metrics.enable!
      expect(metrics.enabled).to be true

      expect(client).to receive(:increment)
      metrics.increment('test.counter')
    end
  end

  describe 'namespace handling' do
    let(:client) { double('statsd_client') }

    it 'prepends namespace to metric names' do
      metrics = described_class.new(backend: :statsd, client: client, namespace: 'myapp')
      expect(client).to receive(:increment).with('myapp.test.counter', 1, tags: [])
      metrics.increment('test.counter')
    end

    it 'works without namespace' do
      metrics = described_class.new(backend: :statsd, client: client, namespace: nil)
      expect(client).to receive(:increment).with('test.counter', 1, tags: [])
      metrics.increment('test.counter')
    end
  end

  describe 'default tags' do
    let(:client) { double('statsd_client') }

    it 'merges default tags with metric tags' do
      metrics = described_class.new(
        backend: :statsd,
        client: client,
        tags: { env: 'production', service: 'kaito' }
      )

      # Allow flexible tag ordering
      expect(client).to receive(:increment) do |metric, value, opts|
        expect(metric).to eq('kaito.test.counter')
        expect(value).to eq(1)
        expect(opts[:tags]).to include('env:production')
        expect(opts[:tags]).to include('service:kaito')
        expect(opts[:tags]).to include('operation:split')
      end

      metrics.increment('test.counter', tags: { operation: 'split' })
    end

    it 'metric tags override default tags' do
      metrics = described_class.new(
        backend: :statsd,
        client: client,
        tags: { env: 'development' }
      )

      expect(client).to receive(:increment).with(
        'kaito.test.counter',
        1,
        tags: ['env:production']
      )

      metrics.increment('test.counter', tags: { env: 'production' })
    end
  end

  describe 'adapter compatibility' do
    context 'when client does not respond to method' do
      let(:minimal_client) { double('minimal_client') }
      let(:metrics) { described_class.new(backend: :custom, client: minimal_client) }

      it 'handles missing increment method gracefully' do
        expect(minimal_client).to receive(:respond_to?).with(:increment).and_return(false)
        expect { metrics.increment('test') }.not_to raise_error
      end

      it 'handles missing timing method gracefully' do
        expect(minimal_client).to receive(:respond_to?).with(:timing).and_return(false)
        expect { metrics.timing('test', 100) }.not_to raise_error
      end

      it 'handles missing gauge method gracefully' do
        expect(minimal_client).to receive(:respond_to?).with(:gauge).and_return(false)
        expect { metrics.gauge('test', 42) }.not_to raise_error
      end
    end
  end

  describe 'integration scenarios' do
    it 'tracks complete split operation' do
      client = double('statsd_client')
      metrics = described_class.new(backend: :statsd, client: client)

      expect(client).to receive(:timing).with('kaito.split.duration', anything, tags: ['strategy:semantic'])
      expect(client).to receive(:increment).with('kaito.split.count', 1, tags: ['strategy:semantic'])
      expect(client).to receive(:gauge).with('kaito.split.chunks', 5, tags: ['strategy:semantic'])
      expect(client).to receive(:gauge).with('kaito.split.tokens', 512, tags: ['strategy:semantic'])

      metrics.track_split(
        strategy: :semantic,
        duration: 1.5,
        chunks: 5,
        tokens: 512
      )
    end

    it 'tracks complete tokenization operation' do
      client = double('statsd_client')
      metrics = described_class.new(backend: :statsd, client: client)

      expect(client).to receive(:timing).with('kaito.tokenization.duration', anything, tags: ['tokenizer:gpt4'])
      expect(client).to receive(:increment).with('kaito.tokenization.count', 1, tags: ['tokenizer:gpt4'])
      expect(client).to receive(:gauge).with('kaito.tokenization.tokens', 256, tags: ['tokenizer:gpt4'])

      metrics.track_tokenization(
        tokenizer: :gpt4,
        duration: 0.5,
        tokens: 256
      )
    end
  end
end
