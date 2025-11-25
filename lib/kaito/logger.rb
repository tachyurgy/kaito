# frozen_string_literal: true

require 'logger'
require 'json'

module Kaito
  # Structured logging for Kaito operations
  #
  # Provides detailed logging of splitting operations, tokenization,
  # and performance metrics with support for both human-readable
  # and JSON formats.
  #
  # @example Basic usage
  #   Kaito.configure do |config|
  #     config.logger = Kaito::Logger.new($stdout, level: :info)
  #   end
  #
  # @example JSON logging
  #   logger = Kaito::Logger.new($stdout, level: :debug, format: :json)
  #   logger.log_split(strategy: :semantic, duration: 1.5, chunks: 10)
  #
  # @example Custom logger
  #   logger = Kaito::Logger.new('kaito.log', level: :warn)
  #   logger.log_error('Failed to split', error: exception)
  class Logger
    attr_reader :logger, :format, :enabled

    # Log levels
    LEVELS = {
      debug: ::Logger::DEBUG,
      info: ::Logger::INFO,
      warn: ::Logger::WARN,
      error: ::Logger::ERROR,
      fatal: ::Logger::FATAL
    }.freeze

    # Initialize a new logger
    #
    # @param output [IO, String] output destination (IO object or file path)
    # @param level [Symbol] log level (:debug, :info, :warn, :error, :fatal)
    # @param format [Symbol] log format (:text, :json)
    # @param enabled [Boolean] whether logging is enabled
    def initialize(output = $stdout, level: :info, format: :text, enabled: true)
      @logger = ::Logger.new(output)
      @logger.level = LEVELS.fetch(level, ::Logger::INFO)
      @format = format
      @enabled = enabled

      configure_formatter
    end

    # Log a text splitting operation
    #
    # @param strategy [Symbol] the splitting strategy used
    # @param duration [Float] operation duration in seconds
    # @param chunks [Integer] number of chunks created
    # @param tokens_processed [Integer] total tokens processed
    # @param text_length [Integer] length of input text
    # @param metadata [Hash] additional metadata
    def log_split(strategy:, duration:, chunks:, tokens_processed: nil, text_length: nil, **metadata)
      return unless enabled

      log_data = {
        operation: 'text_split',
        strategy: strategy,
        duration_seconds: duration.round(3),
        chunks_created: chunks,
        tokens_processed: tokens_processed,
        text_length: text_length,
        timestamp: Time.now.utc.iso8601
      }.merge(metadata).compact

      log_info('Text split completed', log_data)
    end

    # Log a tokenization operation
    #
    # @param tokenizer [Symbol] the tokenizer used
    # @param duration [Float] operation duration in seconds
    # @param token_count [Integer] number of tokens counted
    # @param text_length [Integer] length of input text
    # @param metadata [Hash] additional metadata
    def log_tokenization(tokenizer:, duration:, token_count:, text_length: nil, **metadata)
      return unless enabled

      log_data = {
        operation: 'tokenization',
        tokenizer: tokenizer,
        duration_seconds: duration.round(3),
        token_count: token_count,
        text_length: text_length,
        timestamp: Time.now.utc.iso8601
      }.merge(metadata).compact

      log_debug('Tokenization completed', log_data)
    end

    # Log a file streaming operation
    #
    # @param file_path [String] path to the file
    # @param duration [Float] operation duration in seconds
    # @param chunks [Integer] number of chunks streamed
    # @param file_size [Integer] size of file in bytes
    # @param metadata [Hash] additional metadata
    def log_streaming(file_path:, duration:, chunks:, file_size: nil, **metadata)
      return unless enabled

      log_data = {
        operation: 'file_streaming',
        file_path: file_path,
        duration_seconds: duration.round(3),
        chunks_streamed: chunks,
        file_size_bytes: file_size,
        timestamp: Time.now.utc.iso8601
      }.merge(metadata).compact

      log_info('File streaming completed', log_data)
    end

    # Log performance metrics
    #
    # @param operation [String] the operation name
    # @param duration [Float] operation duration in seconds
    # @param metadata [Hash] additional metrics
    def log_performance(operation:, duration:, **metadata)
      return unless enabled

      log_data = {
        operation: operation,
        duration_seconds: duration.round(3),
        timestamp: Time.now.utc.iso8601
      }.merge(metadata).compact

      log_debug('Performance metric', log_data)
    end

    # Log an error
    #
    # @param message [String] error message
    # @param error [Exception] exception object
    # @param metadata [Hash] additional context
    def log_error(message, error: nil, **metadata)
      return unless enabled

      log_data = {
        message: message,
        timestamp: Time.now.utc.iso8601
      }.merge(metadata)

      if error
        log_data[:error_class] = error.class.name
        log_data[:error_message] = error.message
        log_data[:backtrace] = error.backtrace&.first(5)
      end

      if @format == :json
        @logger.error(log_data.to_json)
      else
        error_text = format_text_log('ERROR', message, log_data)
        @logger.error(error_text)
      end
    end

    # Log a warning
    #
    # @param message [String] warning message
    # @param metadata [Hash] additional context
    def log_warning(message, **metadata)
      return unless enabled

      log_data = {
        message: message,
        timestamp: Time.now.utc.iso8601
      }.merge(metadata).compact

      if @format == :json
        @logger.warn(log_data.to_json)
      else
        @logger.warn(format_text_log('WARN', message, log_data))
      end
    end

    # Enable logging
    def enable!
      @enabled = true
    end

    # Disable logging
    def disable!
      @enabled = false
    end

    # Check if debug level is enabled
    #
    # @return [Boolean]
    def debug?
      @logger.debug?
    end

    # Check if info level is enabled
    #
    # @return [Boolean]
    def info?
      @logger.info?
    end

    private

    def configure_formatter
      if @format == :json
        @logger.formatter = proc do |_severity, _datetime, _progname, msg|
          "#{msg}\n"
        end
      else
        @logger.formatter = proc do |severity, datetime, _progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
        end
      end
    end

    def log_info(message, data)
      if @format == :json
        @logger.info(data.merge(level: 'info', message: message).to_json)
      else
        @logger.info(format_text_log('INFO', message, data))
      end
    end

    def log_debug(message, data)
      if @format == :json
        @logger.debug(data.merge(level: 'debug', message: message).to_json)
      else
        @logger.debug(format_text_log('DEBUG', message, data))
      end
    end

    def format_text_log(_level, message, data)
      parts = [message]

      # Format key metrics
      if data[:duration_seconds]
        parts << "duration=#{data[:duration_seconds]}s"
      end

      if data[:chunks_created]
        parts << "chunks=#{data[:chunks_created]}"
      elsif data[:chunks_streamed]
        parts << "chunks=#{data[:chunks_streamed]}"
      end

      if data[:tokens_processed]
        parts << "tokens=#{data[:tokens_processed]}"
      elsif data[:token_count]
        parts << "tokens=#{data[:token_count]}"
      end

      if data[:strategy]
        parts << "strategy=#{data[:strategy]}"
      end

      if data[:tokenizer]
        parts << "tokenizer=#{data[:tokenizer]}"
      end

      # Add remaining metadata
      excluded_keys = [:message, :level, :timestamp, :operation, :duration_seconds,
                      :chunks_created, :chunks_streamed, :tokens_processed,
                      :token_count, :strategy, :tokenizer]

      remaining = data.reject { |k, _v| excluded_keys.include?(k) }
      unless remaining.empty?
        metadata_str = remaining.map { |k, v| "#{k}=#{v}" }.join(' ')
        parts << metadata_str
      end

      parts.join(' | ')
    end
  end
end
