# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'json'

RSpec.describe Kaito::Logger do
  let(:output) { StringIO.new }

  describe '#initialize' do
    it 'creates a logger with default settings' do
      logger = described_class.new(output)
      expect(logger.enabled).to be true
      expect(logger.format).to eq(:text)
    end

    it 'accepts custom log level' do
      logger = described_class.new(output, level: :debug)
      expect(logger).to be_debug
    end

    it 'accepts JSON format' do
      logger = described_class.new(output, format: :json)
      expect(logger.format).to eq(:json)
    end

    it 'can be initialized as disabled' do
      logger = described_class.new(output, enabled: false)
      expect(logger.enabled).to be false
    end
  end

  describe '#log_split' do
    context 'with text format' do
      let(:logger) { described_class.new(output, level: :info, format: :text) }

      it 'logs split operation with key metrics' do
        logger.log_split(
          strategy: :semantic,
          duration: 1.234,
          chunks: 5,
          tokens_processed: 512,
          text_length: 1000
        )

        log_output = output.string
        expect(log_output).to include('Text split completed')
        expect(log_output).to include('duration=1.234s')
        expect(log_output).to include('chunks=5')
        expect(log_output).to include('tokens=512')
        expect(log_output).to include('strategy=semantic')
      end

      it 'handles optional parameters' do
        logger.log_split(strategy: :character, duration: 0.5, chunks: 3)

        log_output = output.string
        expect(log_output).to include('chunks=3')
        expect(log_output).not_to include('tokens=')
      end

      it 'includes additional metadata' do
        logger.log_split(
          strategy: :semantic,
          duration: 1.0,
          chunks: 2,
          custom_field: 'value'
        )

        log_output = output.string
        expect(log_output).to include('custom_field=value')
      end
    end

    context 'with JSON format' do
      let(:logger) { described_class.new(output, level: :info, format: :json) }

      it 'logs split operation as JSON' do
        logger.log_split(
          strategy: :semantic,
          duration: 1.234,
          chunks: 5,
          tokens_processed: 512
        )

        log_data = JSON.parse(output.string)
        expect(log_data['operation']).to eq('text_split')
        expect(log_data['strategy']).to eq('semantic')
        expect(log_data['duration_seconds']).to eq(1.234)
        expect(log_data['chunks_created']).to eq(5)
        expect(log_data['tokens_processed']).to eq(512)
        expect(log_data).to include('timestamp')
      end
    end

    context 'when disabled' do
      let(:logger) { described_class.new(output, enabled: false) }

      it 'does not log anything' do
        logger.log_split(strategy: :semantic, duration: 1.0, chunks: 5)
        expect(output.string).to be_empty
      end
    end
  end

  describe '#log_tokenization' do
    let(:logger) { described_class.new(output, level: :debug, format: :text) }

    it 'logs tokenization operation' do
      logger.log_tokenization(
        tokenizer: :gpt4,
        duration: 0.123,
        token_count: 256,
        text_length: 500
      )

      log_output = output.string
      expect(log_output).to include('Tokenization completed')
      expect(log_output).to include('duration=0.123s')
      expect(log_output).to include('tokens=256')
      expect(log_output).to include('tokenizer=gpt4')
    end

    it 'uses debug level' do
      logger_info = described_class.new(output, level: :info)
      logger_info.log_tokenization(
        tokenizer: :gpt4,
        duration: 0.1,
        token_count: 100
      )

      expect(output.string).to be_empty
    end
  end

  describe '#log_streaming' do
    let(:logger) { described_class.new(output, level: :info, format: :text) }

    it 'logs file streaming operation' do
      logger.log_streaming(
        file_path: '/path/to/file.txt',
        duration: 2.5,
        chunks: 10,
        file_size: 10_000
      )

      log_output = output.string
      expect(log_output).to include('File streaming completed')
      expect(log_output).to include('duration=2.5s')
      expect(log_output).to include('chunks=10')
    end
  end

  describe '#log_performance' do
    let(:logger) { described_class.new(output, level: :debug, format: :json) }

    it 'logs performance metrics' do
      logger.log_performance(
        operation: 'custom_op',
        duration: 1.5,
        custom_metric: 'value'
      )

      log_data = JSON.parse(output.string)
      expect(log_data['operation']).to eq('custom_op')
      expect(log_data['duration_seconds']).to eq(1.5)
      expect(log_data['custom_metric']).to eq('value')
    end
  end

  describe '#log_error' do
    let(:logger) { described_class.new(output, level: :error, format: :text) }

    it 'logs error with message' do
      logger.log_error('Something failed')

      log_output = output.string
      expect(log_output).to include('ERROR')
      expect(log_output).to include('Something failed')
    end

    it 'includes exception details' do
      error = StandardError.new('Test error')
      error.set_backtrace(['line1', 'line2', 'line3'])

      logger.log_error('Operation failed', error: error)

      log_output = output.string
      expect(log_output).to include('Operation failed')
      expect(log_output).to include('StandardError')
      expect(log_output).to include('Test error')
    end

    context 'with JSON format' do
      let(:logger) { described_class.new(output, level: :error, format: :json) }

      it 'logs error as JSON with exception details' do
        error = RuntimeError.new('Boom')
        error.set_backtrace(['backtrace_line'])

        logger.log_error('Failed', error: error, context: 'test')

        log_data = JSON.parse(output.string)
        expect(log_data['message']).to eq('Failed')
        expect(log_data['error_class']).to eq('RuntimeError')
        expect(log_data['error_message']).to eq('Boom')
        expect(log_data['backtrace']).to be_an(Array)
        expect(log_data['context']).to eq('test')
      end
    end
  end

  describe '#log_warning' do
    let(:logger) { described_class.new(output, level: :warn, format: :text) }

    it 'logs warning message' do
      logger.log_warning('This is a warning', context: 'test')

      log_output = output.string
      expect(log_output).to include('WARN')
      expect(log_output).to include('This is a warning')
    end
  end

  describe '#enable! and #disable!' do
    let(:logger) { described_class.new(output) }

    it 'can be dynamically enabled and disabled' do
      logger.disable!
      expect(logger.enabled).to be false

      logger.log_split(strategy: :semantic, duration: 1.0, chunks: 5)
      expect(output.string).to be_empty

      logger.enable!
      expect(logger.enabled).to be true

      logger.log_split(strategy: :semantic, duration: 1.0, chunks: 5)
      expect(output.string).not_to be_empty
    end
  end

  describe 'log level checks' do
    it 'checks debug level' do
      debug_logger = described_class.new(output, level: :debug)
      info_logger = described_class.new(output, level: :info)

      expect(debug_logger).to be_debug
      expect(info_logger).not_to be_debug
    end

    it 'checks info level' do
      info_logger = described_class.new(output, level: :info)
      warn_logger = described_class.new(output, level: :warn)

      expect(info_logger).to be_info
      expect(warn_logger).not_to be_info
    end
  end

  describe 'log formatting' do
    context 'with text format' do
      let(:logger) { described_class.new(output, format: :text) }

      it 'includes timestamp in standard format' do
        logger.log_split(strategy: :semantic, duration: 1.0, chunks: 5)

        log_output = output.string
        expect(log_output).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]/)
      end

      it 'formats metrics consistently' do
        logger.log_split(
          strategy: :semantic,
          duration: 1.234,
          chunks: 5,
          tokens_processed: 512
        )

        log_output = output.string
        expect(log_output).to match(/duration=[\d.]+s/)
        expect(log_output).to match(/chunks=\d+/)
        expect(log_output).to match(/tokens=\d+/)
      end
    end

    context 'with JSON format' do
      let(:logger) { described_class.new(output, format: :json) }

      it 'produces valid JSON' do
        logger.log_split(strategy: :semantic, duration: 1.0, chunks: 5)

        expect { JSON.parse(output.string) }.not_to raise_error
      end

      it 'includes standard fields' do
        logger.log_split(strategy: :semantic, duration: 1.0, chunks: 5)

        log_data = JSON.parse(output.string)
        expect(log_data).to include('timestamp')
        expect(log_data).to include('level')
        expect(log_data).to include('message')
        expect(log_data).to include('operation')
      end

      it 'rounds duration to 3 decimal places' do
        logger.log_split(strategy: :semantic, duration: 1.23456789, chunks: 5)

        log_data = JSON.parse(output.string)
        expect(log_data['duration_seconds']).to eq(1.235)
      end
    end
  end
end
