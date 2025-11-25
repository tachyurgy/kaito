#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/kaito'

LONG_TEXT = <<~TEXT
  The quick brown fox jumps over the lazy dog. This is a simple sentence.
  And here's another one. We need enough text to test chunking properly.

  This is a second paragraph with more content. It contains several sentences
  that should be processed correctly by the semantic splitter. The tokenizer
  should accurately count tokens across different models.
TEXT

LONG_TEXT_REPEATED = (LONG_TEXT * 20)

puts 'Testing Adaptive Overlap with token limits...'
puts '=' * 80

max_chunk_tokens = 512

chunks = Kaito.split(
  LONG_TEXT_REPEATED,
  strategy: :adaptive,
  max_tokens: max_chunk_tokens,
  overlap_tokens: 50,
  tokenizer: :gpt4
)

puts "\nTotal chunks: #{chunks.length}"
puts "\nChunk details:"
chunks.each_with_index do |chunk, i|
  status = chunk.token_count > max_chunk_tokens ? ' ⚠️  EXCEEDS LIMIT' : ' ✓'
  puts "Chunk #{i}: #{chunk.token_count} tokens#{status}"

  next unless chunk.token_count > max_chunk_tokens

  puts "  ERROR: This chunk exceeds max_tokens of #{max_chunk_tokens}!"
  puts "  Overlap tokens: #{chunk.metadata[:overlap_tokens]}"
  puts "  Text preview: #{chunk.text[0..100]}..."
end

puts "\n#{'=' * 80}"

exceeding_chunks = chunks.count { |c| c.token_count > max_chunk_tokens }
if exceeding_chunks.positive?
  puts "❌ PROBLEM FOUND: #{exceeding_chunks} chunk(s) exceed max_tokens limit"
  puts "\nThis is a bug in the AdaptiveOverlap splitter!"
else
  puts '✅ All chunks within token limits'
end
