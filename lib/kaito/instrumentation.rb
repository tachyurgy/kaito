# frozen_string_literal: true

module Kaito
  # ActiveSupport::Notifications-style instrumentation for Kaito
  #
  # Allows applications to subscribe to key events in the text splitting
  # lifecycle and receive detailed metadata about operations.
  #
  # @example Subscribe to all events
  #   Kaito::Instrumentation.subscribe do |event|
  #     puts "Event: #{event.name}"
  #     puts "Duration: #{event.duration}ms"
  #     puts "Payload: #{event.payload.inspect}"
  #   end
  #
  # @example Subscribe to specific event
  #   Kaito::Instrumentation.subscribe('text_split.kaito') do |event|
  #     StatsD.timing('kaito.split', event.duration)
  #   end
  #
  # @example Using instrumenter directly
  #   Kaito::Instrumentation.instrument('custom.kaito', metadata: 'value') do
  #     # your code here
  #   end
  class Instrumentation
    # Event object containing instrumentation data
    class Event
      attr_reader :name, :payload, :started_at, :finished_at

      # @param name [String] event name
      # @param payload [Hash] event data
      # @param started_at [Time] when the event started
      # @param finished_at [Time] when the event finished
      def initialize(name, payload, started_at, finished_at)
        @name = name
        @payload = payload.freeze
        @started_at = started_at
        @finished_at = finished_at
      end

      # Duration of the event in milliseconds
      #
      # @return [Float]
      def duration
        return 0.0 unless started_at && finished_at
        ((finished_at - started_at) * 1000.0).round(2)
      end

      # Duration in seconds
      #
      # @return [Float]
      def duration_seconds
        return 0.0 unless started_at && finished_at
        (finished_at - started_at).round(3)
      end
    end

    class << self
      # Subscribe to instrumentation events
      #
      # @param pattern [String, Regexp, nil] event name pattern (nil for all events)
      # @yield [Event] the instrumentation event
      # @return [Object] subscription identifier
      #
      # @example Subscribe to all events
      #   Kaito::Instrumentation.subscribe { |event| puts event.name }
      #
      # @example Subscribe to specific events
      #   Kaito::Instrumentation.subscribe('text_split.kaito') { |event| ... }
      #
      # @example Subscribe with pattern
      #   Kaito::Instrumentation.subscribe(/\.kaito$/) { |event| ... }
      def subscribe(pattern = nil, &block)
        raise ArgumentError, 'Block required' unless block

        subscriber = {
          pattern: compile_pattern(pattern),
          callback: block
        }

        subscribers << subscriber
        subscriber
      end

      # Unsubscribe from events
      #
      # @param subscriber [Object] subscription identifier returned from subscribe
      def unsubscribe(subscriber)
        subscribers.delete(subscriber)
      end

      # Clear all subscriptions
      def clear_subscriptions
        subscribers.clear
      end

      # Instrument an operation
      #
      # @param name [String] event name
      # @param payload [Hash] event data
      # @yield block to be instrumented
      # @return result of the block
      #
      # @example
      #   result = Kaito::Instrumentation.instrument('custom.kaito', foo: 'bar') do
      #     # operation code
      #   end
      def instrument(name, payload = {})
        return yield if subscribers.empty?

        started_at = Time.now
        result = nil

        begin
          result = yield
        ensure
          finished_at = Time.now
          event = Event.new(name, payload, started_at, finished_at)
          publish(event)
        end

        result
      end

      # Instrument a text splitting operation
      #
      # @param strategy [Symbol] splitting strategy
      # @param text_length [Integer] length of text being split
      # @param max_tokens [Integer] max tokens per chunk
      # @param overlap_tokens [Integer] overlap tokens
      # @param payload [Hash] additional metadata
      # @yield block performing the split
      # @return result of the block
      def instrument_split(strategy:, text_length:, max_tokens:, overlap_tokens: 0, **payload)
        event_payload = {
          strategy: strategy,
          text_length: text_length,
          max_tokens: max_tokens,
          overlap_tokens: overlap_tokens,
          **payload
        }

        result = nil
        instrument('text_split.kaito', event_payload) do
          result = yield
          # Add result metadata to the event payload BEFORE event is created
          event_payload[:chunks_created] = result.size
          event_payload[:tokens_processed] = result.sum(&:token_count)
          result
        end

        result
      end

      # Instrument a tokenization operation
      #
      # @param tokenizer [Symbol] tokenizer being used
      # @param text_length [Integer] length of text
      # @param payload [Hash] additional metadata
      # @yield block performing tokenization
      # @return result of the block
      def instrument_tokenization(tokenizer:, text_length:, **payload)
        event_payload = {
          tokenizer: tokenizer,
          text_length: text_length,
          **payload
        }

        result = nil
        instrument('tokenization.kaito', event_payload) do
          result = yield
          event_payload[:token_count] = result
          result
        end

        result
      end

      # Instrument file streaming operation
      #
      # @param file_path [String] path to file
      # @param file_size [Integer] size of file in bytes
      # @param strategy [Symbol] splitting strategy
      # @param payload [Hash] additional metadata
      # @yield block performing streaming
      # @return result of the block
      def instrument_streaming(file_path:, file_size:, strategy:, **payload)
        event_payload = {
          file_path: file_path,
          file_size: file_size,
          strategy: strategy,
          **payload
        }

        chunks_count = 0
        result = nil
        instrument('file_streaming.kaito', event_payload) do
          result = yield ->(chunk) { chunks_count += 1 }
          event_payload[:chunks_streamed] = chunks_count
          result
        end

        result
      end

      # Check if instrumentation is enabled (has subscribers)
      #
      # @return [Boolean]
      def enabled?
        !subscribers.empty?
      end

      # Get count of active subscribers
      #
      # @return [Integer]
      def subscriber_count
        subscribers.size
      end

      private

      def subscribers
        @subscribers ||= []
      end

      def compile_pattern(pattern)
        case pattern
        when nil
          ->(_name) { true }
        when String
          ->(name) { name == pattern }
        when Regexp
          ->(name) { pattern.match?(name) }
        else
          raise ArgumentError, "Invalid pattern type: #{pattern.class}"
        end
      end

      def publish(event)
        subscribers.each do |subscriber|
          next unless subscriber[:pattern].call(event.name)

          begin
            subscriber[:callback].call(event)
          rescue StandardError => e
            warn "Error in instrumentation subscriber: #{e.message}"
          end
        end
      end
    end
  end
end
