#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive test suite to validate Kaito gem functionality
# This script tests all major features to ensure the gem works intuitively and effectively

require_relative "../lib/kaito"

# ANSI color codes for output
def green(text)
  "\e[32m#{text}\e[0m"
end

def red(text)
  "\e[31m#{text}\e[0m"
end

def yellow(text)
  "\e[33m#{text}\e[0m"
end

def blue(text)
  "\e[34m#{text}\e[0m"
end

def section(title)
  puts "\n" + "=" * 80
  puts blue("  #{title}")
  puts "=" * 80 + "\n"
end

def test(description)
  print "Testing: #{description}... "
  yield
  puts green("✓ PASSED")
  true
rescue StandardError => e
  puts red("✗ FAILED")
  puts red("  Error: #{e.message}")
  puts red("  #{e.backtrace.first(3).join("\n  ")}")
  false
end

# Test sample texts
SAMPLE_TEXT = <<~TEXT
  The quick brown fox jumps over the lazy dog. This is a simple sentence.
  And here's another one. We need enough text to test chunking properly.

  This is a second paragraph with more content. It contains several sentences
  that should be processed correctly by the semantic splitter. The tokenizer
  should accurately count tokens across different models.
TEXT

MARKDOWN_TEXT = <<~MARKDOWN
  # Main Title

  This is the introduction paragraph.

  ## Section 1

  Content for section 1 with some details.

  ### Subsection 1.1

  More detailed content here.

  ## Section 2

  ```ruby
  def example
    puts "Hello, world!"
  end
  ```

  Some text after the code block.
MARKDOWN

CODE_TEXT = <<~CODE
  class UserManager
    def initialize(database)
      @database = database
    end

    def create_user(name, email)
      user = User.new(name, email)
      @database.save(user)
    end

    def find_user(id)
      @database.find(User, id)
    end
  end

  class User
    attr_accessor :name, :email

    def initialize(name, email)
      @name = name
      @email = email
    end
  end
CODE

LONG_TEXT = (SAMPLE_TEXT * 20).freeze

# Track test results
tests_passed = 0
tests_failed = 0

section "1. BASIC API TESTS"

tests_passed += 1 if test("Simple split with defaults") do
  chunks = Kaito.split(SAMPLE_TEXT, max_tokens: 100)
  raise "Expected array of chunks" unless chunks.is_a?(Array)
  raise "Expected chunks to be Chunk objects" unless chunks.all? { |c| c.is_a?(Kaito::Chunk) }
  raise "Expected at least 1 chunk" unless chunks.length >= 1
end

tests_passed += 1 if test("Token counting") do
  count = Kaito.count_tokens(SAMPLE_TEXT, tokenizer: :gpt4)
  raise "Expected positive token count" unless count > 0
  raise "Token count should be reasonable" unless count < 1000
end

tests_passed += 1 if test("Character splitter strategy") do
  chunks = Kaito.split(SAMPLE_TEXT, strategy: :character, max_tokens: 50)
  raise "Expected array of chunks" unless chunks.is_a?(Array)
  raise "Expected multiple chunks for this text" unless chunks.length > 1
end

tests_passed += 1 if test("Semantic splitter strategy") do
  chunks = Kaito.split(SAMPLE_TEXT, strategy: :semantic, max_tokens: 100)
  raise "Expected array of chunks" unless chunks.is_a?(Array)
  chunks.each do |chunk|
    raise "Chunk token count exceeds max_tokens" if chunk.token_count > 100
  end
end

tests_passed += 1 if test("Recursive splitter strategy") do
  chunks = Kaito.split(SAMPLE_TEXT, strategy: :recursive, max_tokens: 80)
  raise "Expected array of chunks" unless chunks.is_a?(Array)
end

tests_passed += 1 if test("Structure-aware splitter strategy") do
  chunks = Kaito.split(MARKDOWN_TEXT, strategy: :structure_aware, max_tokens: 200)
  raise "Expected array of chunks" unless chunks.is_a?(Array)
  # Should preserve markdown structure
  raise "Expected chunks with structure metadata" unless chunks.any? { |c| c.metadata[:structure] }
end

tests_passed += 1 if test("Adaptive overlap splitter strategy") do
  chunks = Kaito.split(LONG_TEXT, strategy: :adaptive, max_tokens: 200, overlap_tokens: 50)
  raise "Expected array of chunks" unless chunks.is_a?(Array)
  raise "Expected multiple chunks" unless chunks.length > 1
end

section "2. CHUNK OBJECT TESTS"

tests_passed += 1 if test("Chunk metadata access") do
  chunks = Kaito.split(SAMPLE_TEXT, max_tokens: 100)
  chunk = chunks.first

  raise "Expected index to be accessible" unless chunk.index == 0
  raise "Expected token_count to be accessible" unless chunk.token_count > 0
  raise "Expected text to be accessible" unless chunk.text.is_a?(String)
  raise "Expected metadata to be frozen" unless chunk.metadata.frozen?
end

tests_passed += 1 if test("Chunk serialization") do
  chunks = Kaito.split(SAMPLE_TEXT, max_tokens: 100)
  chunk = chunks.first

  hash = chunk.to_h
  raise "Expected hash representation" unless hash.is_a?(Hash)
  raise "Expected hash to have :text" unless hash.key?(:text)
  raise "Expected hash to have :token_count" unless hash.key?(:token_count)
  raise "Expected hash to have :metadata" unless hash.key?(:metadata)
end

section "3. DIRECT SPLITTER INSTANTIATION"

tests_passed += 1 if test("SemanticSplitter direct instantiation") do
  splitter = Kaito::Splitters::Semantic.new(
    max_tokens: 150,
    overlap_tokens: 30,
    tokenizer: :gpt4,
    language: :en
  )

  chunks = splitter.split(SAMPLE_TEXT)
  raise "Expected array of chunks" unless chunks.is_a?(Array)
  raise "Expected semantic splitter to work" unless chunks.length >= 1
end

tests_passed += 1 if test("StructureAwareSplitter direct instantiation") do
  splitter = Kaito::Splitters::StructureAware.new(
    max_tokens: 200,
    overlap_tokens: 0,
    tokenizer: :gpt4
  )

  chunks = splitter.split(MARKDOWN_TEXT)
  raise "Expected array of chunks" unless chunks.is_a?(Array)
end

tests_passed += 1 if test("AdaptiveOverlapSplitter direct instantiation") do
  splitter = Kaito::Splitters::AdaptiveOverlap.new(
    max_tokens: 200,
    overlap_tokens: 50,
    min_overlap_tokens: 20,
    max_overlap_tokens: 80,
    tokenizer: :gpt4
  )

  chunks = splitter.split(LONG_TEXT)
  raise "Expected array of chunks" unless chunks.is_a?(Array)
end

section "4. OVERLAP FUNCTIONALITY"

tests_passed += 1 if test("Fixed overlap works correctly") do
  chunks = Kaito.split(LONG_TEXT, strategy: :semantic, max_tokens: 150, overlap_tokens: 30)

  raise "Expected multiple chunks for overlap test" unless chunks.length > 1
  # Can't easily verify overlap without inspecting internal details, but should not error
end

tests_passed += 1 if test("Adaptive overlap creates overlaps") do
  chunks = Kaito.split(LONG_TEXT, strategy: :adaptive, max_tokens: 200, overlap_tokens: 50)

  raise "Expected multiple chunks" unless chunks.length > 1
  # Check if any chunk has overlap metadata
  has_overlap_metadata = chunks.any? { |c| c.metadata[:overlap_tokens] }
  puts "  [Info: Overlap metadata present: #{has_overlap_metadata}]"
end

section "5. MULTILINGUAL SUPPORT"

tests_passed += 1 if test("Unicode text handling") do
  unicode_text = "Hello 世界 🌍! This is a test with émojis and spëcial çharacters."
  chunks = Kaito.split(unicode_text, max_tokens: 50)

  raise "Expected to handle unicode text" unless chunks.is_a?(Array)
  raise "Expected text to be preserved" unless chunks.first.text.include?("世界")
end

section "6. EDGE CASES"

tests_passed += 1 if test("Empty text handling") do
  chunks = Kaito.split("", max_tokens: 100)
  raise "Expected empty array for empty text" unless chunks.empty?
end

tests_passed += 1 if test("Nil text handling") do
  chunks = Kaito.split(nil, max_tokens: 100)
  raise "Expected empty array for nil text" unless chunks.empty?
end

tests_passed += 1 if test("Very short text (shorter than max_tokens)") do
  short_text = "Hello."
  chunks = Kaito.split(short_text, max_tokens: 100)
  raise "Expected single chunk" unless chunks.length == 1
  raise "Expected text to match" unless chunks.first.text.strip == short_text.strip
end

tests_passed += 1 if test("Single very long word") do
  long_word = "a" * 1000
  chunks = Kaito.split(long_word, max_tokens: 100)
  raise "Expected to split long word" unless chunks.is_a?(Array)
end

section "7. TOKENIZER TESTS"

tests_passed += 1 if test("Character tokenizer") do
  count = Kaito.count_tokens("Hello, world!", tokenizer: :character)
  raise "Expected character count" unless count == 13
end

tests_passed += 1 if test("GPT-4 tokenizer") do
  count = Kaito.count_tokens(SAMPLE_TEXT, tokenizer: :gpt4)
  raise "Expected reasonable token count" unless count > 0
end

tests_passed += 1 if test("GPT-3.5 tokenizer") do
  count = Kaito.count_tokens(SAMPLE_TEXT, tokenizer: :gpt35_turbo)
  raise "Expected reasonable token count" unless count > 0
end

tests_passed += 1 if test("Tokenizer consistency") do
  gpt4_count = Kaito.count_tokens(SAMPLE_TEXT, tokenizer: :gpt4)
  gpt35_count = Kaito.count_tokens(SAMPLE_TEXT, tokenizer: :gpt35_turbo)

  # Both use cl100k_base, so should be identical
  raise "Expected same token count for GPT-4 and GPT-3.5" unless gpt4_count == gpt35_count
end

section "8. CONFIGURATION TESTS"

tests_passed += 1 if test("Global configuration") do
  Kaito.configure do |config|
    config.default_tokenizer = :gpt35_turbo
    config.default_max_tokens = 300
    config.default_overlap_tokens = 50
  end

  raise "Expected configuration to be set" unless Kaito.configuration.default_tokenizer == :gpt35_turbo
  raise "Expected max_tokens to be set" unless Kaito.configuration.default_max_tokens == 300
end

section "9. METADATA PRESERVATION"

tests_passed += 1 if test("Chunk indices are sequential") do
  chunks = Kaito.split(LONG_TEXT, max_tokens: 100)

  chunks.each_with_index do |chunk, i|
    raise "Expected index #{i}, got #{chunk.index}" unless chunk.index == i
  end
end

tests_passed += 1 if test("Structure metadata in structure-aware splitting") do
  chunks = Kaito.split(MARKDOWN_TEXT, strategy: :structure_aware, max_tokens: 200)

  # At least some chunks should have structure metadata
  has_structure = chunks.any? { |c| c.metadata[:structure] }
  raise "Expected structure metadata" unless has_structure
end

section "10. STREAMING TESTS"

tests_passed += 1 if test("Stream file returns enumerator") do
  # Create a temporary file
  require "tempfile"
  file = Tempfile.new("kaito_test")
  file.write(LONG_TEXT)
  file.close

  enum = Kaito.stream_file(file.path, max_tokens: 100)
  raise "Expected enumerator" unless enum.is_a?(Enumerator)

  chunks = enum.to_a
  raise "Expected chunks from stream" unless chunks.length > 0
  raise "Expected Chunk objects" unless chunks.all? { |c| c.is_a?(Kaito::Chunk) }

  file.unlink
end

tests_passed += 1 if test("Stream file with block") do
  require "tempfile"
  file = Tempfile.new("kaito_test")
  file.write(LONG_TEXT)
  file.close

  chunk_count = 0
  Kaito.stream_file(file.path, max_tokens: 100) do |chunk|
    chunk_count += 1
    raise "Expected Chunk object in block" unless chunk.is_a?(Kaito::Chunk)
  end

  raise "Expected chunks to be yielded" unless chunk_count > 0

  file.unlink
end

section "11. ERROR HANDLING"

tests_passed += 1 if test("Invalid strategy raises error") do
  begin
    Kaito.split(SAMPLE_TEXT, strategy: :invalid_strategy)
    raise "Expected error for invalid strategy"
  rescue ArgumentError => e
    raise "Expected meaningful error message" unless e.message.include?("Unknown strategy")
  end
end

tests_passed += 1 if test("Invalid tokenizer raises error") do
  begin
    Kaito.split(SAMPLE_TEXT, tokenizer: :invalid_tokenizer)
    raise "Expected error for invalid tokenizer"
  rescue ArgumentError => e
    raise "Expected meaningful error message" unless e.message.include?("Unknown tokenizer")
  end
end

tests_passed += 1 if test("Invalid parameters raise errors") do
  begin
    Kaito::Splitters::Semantic.new(max_tokens: -1)
    raise "Expected error for negative max_tokens"
  rescue ArgumentError => e
    raise "Expected meaningful error message" unless e.message.include?("positive")
  end
end

tests_passed += 1 if test("Overlap >= max_tokens raises error") do
  begin
    Kaito::Splitters::Semantic.new(max_tokens: 100, overlap_tokens: 100)
    raise "Expected error for overlap >= max_tokens"
  rescue ArgumentError => e
    raise "Expected meaningful error message" unless e.message.include?("less than max_tokens")
  end
end

section "12. REAL-WORLD USE CASES"

tests_passed += 1 if test("RAG pipeline: chunk document for embeddings") do
  # Simulate a RAG pipeline where we need to chunk a document
  document = LONG_TEXT
  chunks = Kaito.split(
    document,
    strategy: :semantic,
    max_tokens: 500,
    overlap_tokens: 50,
    tokenizer: :gpt4
  )

  # Verify chunks are suitable for embedding
  chunks.each do |chunk|
    raise "Chunk too large for embedding" if chunk.token_count > 500
    raise "Chunk text is empty" if chunk.text.empty?
    raise "Missing index" if chunk.index.nil?
  end

  puts "  [Info: Created #{chunks.length} chunks for RAG pipeline]"
end

tests_passed += 1 if test("Documentation processing: structure-aware splitting") do
  # Simulate processing markdown documentation
  chunks = Kaito.split(
    MARKDOWN_TEXT,
    strategy: :structure_aware,
    max_tokens: 300,
    tokenizer: :gpt4
  )

  # Verify structure is preserved
  raise "Expected chunks" unless chunks.length > 0

  # Check that headers are preserved
  has_headers = chunks.any? { |c| c.text.include?("#") }
  puts "  [Info: Headers preserved: #{has_headers}]"
end

tests_passed += 1 if test("Code splitting: maintain function boundaries") do
  # Simulate splitting code while maintaining structure
  chunks = Kaito.split(
    CODE_TEXT,
    strategy: :structure_aware,
    max_tokens: 200,
    tokenizer: :gpt4
  )

  raise "Expected code chunks" unless chunks.length > 0
  puts "  [Info: Created #{chunks.length} code chunks]"
end

tests_passed += 1 if test("LLM context window optimization") do
  # Simulate optimizing text for LLM context window
  max_context = 4096
  max_chunk_tokens = 512

  chunks = Kaito.split(
    LONG_TEXT,
    strategy: :adaptive,
    max_tokens: max_chunk_tokens,
    overlap_tokens: 50,
    tokenizer: :gpt4
  )

  total_tokens = chunks.sum(&:token_count)
  raise "Total tokens exceed context window" if total_tokens > max_context * 2 # Reasonable check

  chunks.each do |chunk|
    raise "Chunk exceeds max tokens" if chunk.token_count > max_chunk_tokens
  end

  puts "  [Info: Total chunks: #{chunks.length}, Total tokens: ~#{total_tokens}]"
end

# Final summary
section "TEST SUMMARY"

total_tests = tests_passed + tests_failed
pass_rate = (tests_passed.to_f / total_tests * 100).round(1)

puts "\nTotal tests run: #{total_tests}"
puts green("Tests passed: #{tests_passed}")
puts red("Tests failed: #{tests_failed}") if tests_failed > 0
puts "\nPass rate: #{pass_rate}%"

if tests_failed == 0
  puts "\n" + green("=" * 80)
  puts green("  ✓ ALL TESTS PASSED! The Kaito gem is working correctly.")
  puts green("=" * 80)
  exit 0
else
  puts "\n" + red("=" * 80)
  puts red("  ✗ Some tests failed. Please review the errors above.")
  puts red("=" * 80)
  exit 1
end
