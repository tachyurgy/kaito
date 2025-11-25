#!/usr/bin/env ruby
# frozen_string_literal: true

# Test edge cases and potential issues

require_relative '../lib/kaito'

puts 'Testing Edge Cases and Potential Issues'
puts '=' * 80

# Test 1: Very small max_tokens
puts "\n1. Very small max_tokens (10 tokens):"
begin
  text = 'This is a test sentence with more than ten tokens for sure.'
  chunks = Kaito.split(text, max_tokens: 10, strategy: :semantic)
  puts "   ✓ Created #{chunks.length} chunks"
  chunks.each_with_index do |chunk, i|
    puts "   ⚠️  Chunk #{i}: #{chunk.token_count} tokens (EXCEEDS LIMIT!)" if chunk.token_count > 10
  end
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 2: max_tokens = 1
puts "\n2. Extreme case: max_tokens = 1:"
begin
  text = 'Hello world'
  chunks = Kaito.split(text, max_tokens: 1, strategy: :character)
  puts "   ✓ Created #{chunks.length} chunks"
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 3: Text with only whitespace
puts "\n3. Text with only whitespace:"
begin
  text = "     \n\n\t\t   \n   "
  chunks = Kaito.split(text, max_tokens: 100)
  puts "   ✓ Created #{chunks.length} chunks (empty text handling)"
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 4: Text with special characters
puts "\n4. Text with special characters and emojis:"
begin
  text = 'Hello 🌍 世界! This has émojis 🎉 and spëcial çharacters © ™ ® ñ ü ö'
  chunks = Kaito.split(text, max_tokens: 20)
  puts "   ✓ Created #{chunks.length} chunks"
  puts "   Text preserved: #{chunks.first.text.include?('🌍')}"
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 5: All strategies with small text
puts "\n5. All strategies with small text:"
text = 'Short text.'
%i[character semantic recursive structure_aware adaptive].each do |strategy|
  chunks = Kaito.split(text, strategy: strategy, max_tokens: 100)
  puts "   ✓ #{strategy}: #{chunks.length} chunk(s)"
rescue StandardError => e
  puts "   ✗ #{strategy}: Error - #{e.message}"
end

# Test 6: Markdown with only headers (no content)
puts "\n6. Markdown with only headers:"
begin
  text = "# Header 1\n## Header 2\n### Header 3"
  chunks = Kaito.split(text, strategy: :structure_aware, max_tokens: 100)
  puts "   ✓ Created #{chunks.length} chunks"
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 7: Code block detection
puts "\n7. Code block without markdown markers:"
begin
  code = <<~CODE
    def hello
      puts "world"
    end
  CODE
  chunks = Kaito.split(code, strategy: :structure_aware, max_tokens: 100)
  puts "   ✓ Created #{chunks.length} chunks"
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 8: Very large overlap (close to max_tokens)
puts "\n8. Very large overlap (90% of max_tokens):"
begin
  text = 'This is a test sentence. ' * 100
  chunks = Kaito.split(text, max_tokens: 100, overlap_tokens: 90, strategy: :semantic)
  puts "   ✓ Created #{chunks.length} chunks"
  exceeding = chunks.count { |c| c.token_count > 100 }
  puts "   ⚠️  #{exceeding} chunks exceed max_tokens!" if exceeding.positive?
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 9: Single sentence longer than max_tokens
puts "\n9. Single sentence longer than max_tokens:"
begin
  long_sentence = "#{'This is a very long sentence ' * 50}."
  chunks = Kaito.split(long_sentence, max_tokens: 20, strategy: :semantic)
  puts "   ✓ Created #{chunks.length} chunks"
  chunks.each_with_index do |chunk, i|
    puts "   ⚠️  Chunk #{i}: #{chunk.token_count} tokens (EXCEEDS!)" if chunk.token_count > 20
  end
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 10: Recursive splitter with custom separators
puts "\n10. Recursive splitter behavior:"
begin
  text = "Section A\n\nSection B\n\nSection C"
  chunks = Kaito.split(text, strategy: :recursive, max_tokens: 20)
  puts "   ✓ Created #{chunks.length} chunks"
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 11: Streaming non-existent file
puts "\n11. Streaming non-existent file:"
begin
  Kaito.stream_file('/nonexistent/file.txt', max_tokens: 100) do |chunk|
    puts "Got chunk: #{chunk}"
  end
  puts '   ✗ Should have raised error!'
rescue Kaito::FileError => e
  puts "   ✓ Correctly raised FileError: #{e.message}"
rescue StandardError => e
  puts "   ⚠️  Raised unexpected error: #{e.class} - #{e.message}"
end

# Test 12: Thread safety (basic check)
puts "\n12. Basic concurrency test (creating multiple splitters):"
begin
  threads = 5.times.map do |i|
    Thread.new do
      text = "Thread #{i} test text. " * 10
      chunks = Kaito.split(text, max_tokens: 50)
      chunks.length
    end
  end
  results = threads.map(&:value)
  puts "   ✓ All threads completed: #{results.inspect}"
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 13: Memory test with very long text
puts "\n13. Processing very long text (100KB+):"
begin
  huge_text = 'This is a sentence. ' * 10_000
  start_time = Time.now
  chunks = Kaito.split(huge_text, max_tokens: 500, strategy: :semantic)
  elapsed = Time.now - start_time
  puts "   ✓ Created #{chunks.length} chunks in #{elapsed.round(2)}s"
  exceeding = chunks.count { |c| c.token_count > 500 }
  puts "   ⚠️  #{exceeding} chunks exceed max_tokens!" if exceeding.positive?
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 14: Paragraph splitting with various line endings
puts "\n14. Text with different line endings:"
begin
  text_unix = "Para 1\n\nPara 2\n\nPara 3"
  text_windows = "Para 1\r\n\r\nPara 2\r\n\r\nPara 3"
  chunks_unix = Kaito.split(text_unix, max_tokens: 50)
  chunks_windows = Kaito.split(text_windows, max_tokens: 50)
  puts "   ✓ Unix: #{chunks_unix.length} chunks, Windows: #{chunks_windows.length} chunks"
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

# Test 15: Testing the character tokenizer fallback
puts "\n15. Character tokenizer:"
begin
  text = 'Testing character tokenizer'
  count = Kaito.count_tokens(text, tokenizer: :character)
  puts "   ✓ Character count: #{count} (expected: #{text.length})"
  raise 'Count mismatch!' unless count == text.length
rescue StandardError => e
  puts "   ✗ Error: #{e.message}"
end

puts "\n#{'=' * 80}"
puts 'Edge case testing complete!'
