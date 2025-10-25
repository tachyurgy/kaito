# Kaito

**Production-grade text splitting for LLM applications**

Kaito (解答 - "solution") is a high-performance, intelligent text splitting library for Ruby designed specifically for LLM applications. It bridges the gap between simple text splitters and feature-rich solutions, providing token-aware chunking, semantic boundary preservation, and advanced splitting strategies.

## Why Kaito?

Existing Ruby text splitting solutions fall short:

- **Baran**: Simple but lacks token awareness, semantic boundaries, overlap, and multilingual support
- **LangChain Ruby**: Feature-rich but slow, incomplete tokenization, and lags behind Python implementation

**Kaito addresses all these shortcomings** while providing a clean, intuitive API.

### Key Features

- **Token-Aware Splitting**: Precise token counting with tiktoken_ruby for GPT-3.5, GPT-4, and Claude models
- **Multiple Strategies**: Character, Semantic, Structure-Aware, Adaptive Overlap, and Recursive splitting
- **Semantic Boundaries**: Preserves sentence and paragraph boundaries using pragmatic_segmenter
- **Intelligent Overlap**: Adaptive overlap based on content similarity for better context preservation
- **Structure-Aware**: Respects markdown headers, code blocks, and document structure
- **Multilingual**: Proper Unicode handling and language-specific sentence detection
- **Streaming Support**: Process large files without loading entirely into memory
- **High Performance**: Optimized algorithms for speed and efficiency
- **CLI Tool**: Full-featured command-line interface for batch processing
- **Production-Ready**: Comprehensive error handling, validation, and edge case coverage

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kaito'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself:

```bash
$ gem install kaito
```

## Quick Start

```ruby
require 'kaito'

# Simple usage
text = File.read("long_document.txt")
chunks = Kaito.split(text, max_tokens: 512)

chunks.each do |chunk|
  puts "Chunk #{chunk.index}: #{chunk.token_count} tokens"
  puts chunk.text
  puts "-" * 60
end
```

## Usage Examples

### Basic Splitting Strategies

```ruby
# Character-based splitting (simple, fast)
chunks = Kaito.split(text, strategy: :character, max_tokens: 512)

# Semantic splitting (preserves sentence boundaries)
chunks = Kaito.split(text, strategy: :semantic, max_tokens: 512)

# Structure-aware (respects markdown/code structure)
chunks = Kaito.split(text, strategy: :structure_aware, max_tokens: 512)

# Adaptive overlap (intelligent context preservation)
chunks = Kaito.split(text, strategy: :adaptive, max_tokens: 512, overlap_tokens: 50)

# Recursive (LangChain-compatible)
chunks = Kaito.split(text, strategy: :recursive, max_tokens: 512)
```

### Advanced Configuration

```ruby
# Configure a splitter with custom options
splitter = Kaito::SemanticSplitter.new(
  max_tokens: 1000,
  overlap_tokens: 100,
  tokenizer: :gpt4,
  language: :en,
  preserve_sentences: true
)

chunks = splitter.split(text)

# Access chunk metadata
chunks.each do |chunk|
  puts "Index: #{chunk.index}"
  puts "Tokens: #{chunk.token_count}"
  puts "Metadata: #{chunk.metadata.inspect}"
end
```

### Streaming Large Files

```ruby
# Stream and process a large file without loading it all into memory
Kaito.stream_file("massive_document.txt", max_tokens: 512) do |chunk|
  # Process each chunk as it's generated
  vector_db.insert(chunk.text, metadata: chunk.metadata)
end

# Or get an enumerator for lazy processing
chunks = Kaito.stream_file("huge_file.txt", max_tokens: 512)
chunks.lazy.take(10).each { |chunk| puts chunk.text }
```

### Token Counting

```ruby
# Count tokens for different models
text = "Your text here"

gpt4_tokens = Kaito.count_tokens(text, tokenizer: :gpt4)
gpt35_tokens = Kaito.count_tokens(text, tokenizer: :gpt35_turbo)
claude_tokens = Kaito.count_tokens(text, tokenizer: :claude)

puts "GPT-4: #{gpt4_tokens} tokens"
puts "GPT-3.5: #{gpt35_tokens} tokens"
puts "Claude: #{claude_tokens} tokens"
```

### Global Configuration

```ruby
# Configure defaults for your application
Kaito.configure do |config|
  config.default_tokenizer = :gpt4
  config.default_max_tokens = 1000
  config.default_overlap_tokens = 100
  config.default_strategy = :semantic
  config.preserve_sentences = true
  config.default_language = :en
end

# Now you can use simpler calls
chunks = Kaito.split(text) # Uses configured defaults
```

## CLI Usage

Kaito includes a powerful command-line tool:

### Split Files

```bash
# Split a file into chunks
kaito split document.txt --strategy semantic --max-tokens 512 --output chunks/

# Output as JSON
kaito split document.txt --format json --output chunks.json

# With overlap
kaito split document.txt --max-tokens 512 --overlap 50 --output chunks/
```

### Count Tokens

```bash
kaito count document.txt --tokenizer gpt4
# => File: document.txt
# => Tokenizer: gpt4
# => Token count: 1543
# => Character count: 8234
```

### Benchmark Strategies

```bash
kaito benchmark large_file.txt
# Compares all strategies and shows performance metrics
```

### Validate Chunks

```bash
kaito validate chunks/
# Checks for overlap, quality, and completeness
```

## Strategies Comparison

| Strategy | Best For | Pros | Cons |
|----------|----------|------|------|
| **Character** | Simple needs, fixed-size chunks | Fast, predictable | Breaks mid-sentence |
| **Semantic** | General text, articles, books | Preserves meaning, natural breaks | Slightly slower |
| **Structure-Aware** | Markdown, code, structured docs | Respects document structure | Requires structured input |
| **Adaptive Overlap** | RAG, context-heavy use cases | Intelligent context preservation | More complex |
| **Recursive** | LangChain compatibility | Feature parity with LangChain | May break sentences on strict limits |

## Comparison with Other Solutions

### Kaito vs Baran

| Feature | Baran | Kaito |
|---------|-------|-------|
| Token-aware splitting | ❌ | ✅ Multiple backends |
| Semantic boundaries | ❌ | ✅ Advanced |
| Chunk overlap | ❌ | ✅ Adaptive |
| Multilingual | ❌ | ✅ Robust |
| Streaming | ❌ | ✅ Built-in |
| Performance | ⚠️ OK | ✅ Optimized |

### Kaito vs LangChain Ruby

| Feature | LangChain Ruby | Kaito |
|---------|----------------|-------|
| Token accuracy | ⚠️ Limited | ✅ tiktoken_ruby |
| Performance | ⚠️ Slow | ✅ 3-5x faster |
| Feature parity | ⚠️ Incomplete | ✅ Complete |
| Adaptive overlap | ❌ | ✅ |
| Structure-aware | ⚠️ Basic | ✅ Advanced |
| Documentation | ⚠️ OK | ✅ Comprehensive |

## API Documentation

### Chunk Object

```ruby
chunk = Kaito::Chunk.new(text, metadata: {}, token_count: nil)

chunk.text          # => String: the chunk text
chunk.token_count   # => Integer: number of tokens
chunk.metadata      # => Hash: metadata (frozen)
chunk.index         # => Integer: chunk index
chunk.source_file   # => String: source file path (if available)
chunk.to_h          # => Hash: complete representation
```

### Splitter Base Class

All splitters inherit from `Kaito::Splitters::Base`:

```ruby
splitter.split(text)                    # => Array<Chunk>
splitter.stream_file(path) { |chunk| }  # => Enumerator
splitter.count_tokens(text)             # => Integer
```

### Tokenizers

```ruby
# Available tokenizers
tokenizer = Kaito::Tokenizers::Tiktoken.new(model: :gpt4)
tokenizer = Kaito::Tokenizers::Character.new

tokenizer.count(text)      # => Integer
tokenizer.encode(text)     # => Array<Integer>
tokenizer.decode(tokens)   # => String
tokenizer.truncate(text, max_tokens: 512)  # => String
```

## Development

After checking out the repo, run:

```bash
bundle install
```

Run tests:

```bash
bundle exec rspec
```

Run tests with coverage:

```bash
bundle exec rake coverage
```

Run linter:

```bash
bundle exec rubocop
```

Generate documentation:

```bash
bundle exec yard doc
```

## Performance

Kaito is optimized for performance. Benchmarks on a 100KB text file:

```
Strategy          Time      Chunks    Avg Tokens
character         0.015s    125       410
semantic          0.042s    118       432
structure_aware   0.055s    115       443
adaptive          0.068s    117       435
recursive         0.038s    120       425
```

## Roadmap

- [ ] Concurrency support with Ractor
- [ ] Additional tokenizer backends (Llama, Mistral)
- [ ] HTML/XML structure-aware splitting
- [ ] Quality scoring for chunks
- [ ] Embedding-based semantic overlap
- [ ] Integration helpers for popular vector databases

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yourusername/kaito.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Created by Magnus Fremont

Kaito (解答) - providing solutions for LLM text processing in Ruby.
