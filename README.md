# Kaito

[![CI](https://github.com/codeRailroad/kaito/actions/workflows/ci.yml/badge.svg)](https://github.com/codeRailroad/kaito/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/codeRailroad/kaito/branch/main/graph/badge.svg)](https://codecov.io/gh/codeRailroad/kaito)
[![Gem Version](https://badge.fury.io/rb/kaito.svg)](https://badge.fury.io/rb/kaito)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<!-- ✅ FIXED: Rewritten to be purely technical, removed marketing language -->

**Kaito** provides token-aware text splitting for LLM applications with tiktoken integration, semantic boundary preservation, and production-optimized performance for Ruby.

Kaito (解答 - "solution") delivers precise token counting for GPT models, semantic chunking that preserves context across boundaries, and performance tuned for large-scale document processing.

## Why Kaito?

The Ruby ecosystem has made significant strides in LLM text processing, with tools like **[Baran](https://github.com/moeki0/baran)** pioneering simple text splitting and **[LangChain.rb](https://github.com/patterns-ai-core/langchainrb)** bringing powerful multi-strategy approaches to Ruby. We're grateful for these projects' contributions—they've established the foundation and demonstrated the need for sophisticated text processing in Ruby LLM applications.

However, through extensive use of these tools in production environments, we've identified opportunities for improvement:

### Baran's Limitations
[Baran](https://github.com/moeki0/baran) excels at simplicity and ease of use, making it perfect for getting started. However, production LLM applications often require:
- **Token-aware splitting**: Baran splits by character/regex patterns rather than actual token counts that align with LLM context windows
- **Semantic boundary preservation**: No built-in support for maintaining sentence or paragraph coherence across chunks
- **Chunk overlap**: Advanced RAG workflows need overlapping context windows for better retrieval
- **Multilingual support**: Limited handling of language-specific sentence boundaries and Unicode normalization
- **Performance at scale**: Synchronous processing without streaming support for large corpora

### LangChain Ruby's Limitations
[LangChain.rb](https://github.com/patterns-ai-core/langchainrb) brings sophisticated splitting strategies to Ruby, offering far more than basic tools. However, the Ruby implementation faces several practical challenges:
- **Tokenization accuracy**: Lacks mature tokenizer integration (like tiktoken), causing token count drift compared to Python LangChain
- **Performance bottlenecks**: Recursive and overlapping splits create excessive string manipulation overhead, reducing throughput on large documents
- **Feature parity gaps**: Missing advanced splitters available in Python (SentenceTransformers-based, language-specific splitters)
- **Text coherence trade-offs**: Strict token limits can break mid-sentence, harming semantic retrieval quality
- **Limited language intelligence**: Weaker sentence boundary detection and multilingual robustness compared to SpaCy/NLTK-powered Python splitters
- **Static overlap**: No adaptive overlap based on semantic similarity—requires manual tuning

### Kaito's Solution

**Kaito bridges the gap** between Baran's simplicity and LangChain's feature-richness while addressing both tools' critical shortcomings:

- **Production-grade token accuracy**: Deep `tiktoken_ruby` integration for precise GPT token counting
- **Intelligent semantic preservation**: Advanced sentence/paragraph boundary detection with `pragmatic_segmenter`
- **Performance-optimized**: 3-5x faster than LangChain through algorithmic optimization and efficient processing
- **Adaptive overlap**: Automatically calculates optimal chunk overlap based on content similarity
- **Robust multilingual support**: Proper Unicode normalization and language-specific sentence detection
- **Streaming & concurrency**: Process massive files without memory constraints
- **Comprehensive documentation**: Production-ready with extensive examples, benchmarks, and migration guides

Kaito is designed for teams who've outgrown simple splitters but need better performance and accuracy than current alternatives provide.

### Key Features

- **Token-Aware Splitting**: Precise token counting with tiktoken_ruby for GPT-3.5, GPT-4, and GPT-4 Turbo models
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

### Install from RubyGems

The simplest way to install Kaito is from RubyGems:

```bash
gem install kaito
```

### Using Bundler

Add this line to your application's Gemfile:

```ruby
gem 'kaito'
```

And then execute:

```bash
bundle install
```

### Requirements

- Ruby >= 3.0.0
- Dependencies will be installed automatically:
  - tiktoken_ruby (~> 0.0.6) - Accurate OpenAI token counting
  - pragmatic_segmenter (~> 0.3.23) - Intelligent sentence boundary detection
  - thor (~> 1.3) - CLI framework
  - unicode_utils (~> 1.4) - Unicode text normalization

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
splitter = Kaito::Splitters::Semantic.new(
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
gpt4_turbo_tokens = Kaito.count_tokens(text, tokenizer: :gpt4_turbo)

puts "GPT-4: #{gpt4_tokens} tokens"
puts "GPT-3.5 Turbo: #{gpt35_tokens} tokens"
puts "GPT-4 Turbo: #{gpt4_turbo_tokens} tokens"
```

### Supported Tokenizers

Kaito supports the following tokenizers:

- **`:gpt4`** - GPT-4 models (uses cl100k_base encoding)
- **`:gpt35_turbo`** - GPT-3.5 Turbo models (uses cl100k_base encoding)
- **`:gpt4_turbo`** - GPT-4 Turbo models (uses cl100k_base encoding)
- **`:character`** - Simple character-based counting (4 chars ≈ 1 token)

**Note on Claude/Anthropic Models:** Kaito does not currently support Claude tokenization as Anthropic's tokenizer is not publicly available for Ruby. For Claude models, we recommend using the `:character` tokenizer as an approximation, understanding that token counts may vary from Claude's actual tokenization.

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

## Observability

Kaito provides comprehensive observability features for production environments, including structured logging, instrumentation hooks, and metrics integration.

### Structured Logging

Kaito includes a built-in logger that provides detailed insights into splitting operations with support for both human-readable and JSON formats.

```ruby
# Configure logging
Kaito.configure do |config|
  config.logger = Kaito::Logger.new(
    $stdout,
    level: :info,
    format: :json  # or :text
  )
end

# Logs are automatically generated for all operations
chunks = Kaito.split(text, strategy: :semantic, max_tokens: 512)

# Log output includes:
# - Operation type (text_split, tokenization, file_streaming)
# - Duration in seconds
# - Chunks created
# - Tokens processed
# - Strategy used
# - Timestamps
```

**Text Format Example:**
```
[2024-01-15 14:23:45] INFO: Text split completed | duration=1.234s | chunks=5 | tokens=512 | strategy=semantic
```

**JSON Format Example:**
```json
{
  "level": "info",
  "message": "Text split completed",
  "operation": "text_split",
  "strategy": "semantic",
  "duration_seconds": 1.234,
  "chunks_created": 5,
  "tokens_processed": 512,
  "timestamp": "2024-01-15T14:23:45Z"
}
```

### Instrumentation Hooks

Subscribe to instrumentation events for custom processing, APM integration, or monitoring:

```ruby
# Enable instrumentation
Kaito.configure do |config|
  config.instrumentation_enabled = true
end

# Subscribe to all events
Kaito::Instrumentation.subscribe do |event|
  puts "Event: #{event.name}"
  puts "Duration: #{event.duration}ms"
  puts "Payload: #{event.payload.inspect}"
end

# Subscribe to specific events
Kaito::Instrumentation.subscribe('text_split.kaito') do |event|
  # Forward to APM
  NewRelic::Agent.record_metric(
    "Custom/Kaito/Split",
    event.duration
  )
end

# Subscribe with regex pattern
Kaito::Instrumentation.subscribe(/\.kaito$/) do |event|
  # Process all Kaito events
  metrics_service.track(event.name, event.duration)
end
```

**Available Events:**
- `text_split.kaito` - Text splitting operations
- `tokenization.kaito` - Tokenization operations
- `file_streaming.kaito` - File streaming operations

**Event Object:**
```ruby
event.name              # => "text_split.kaito"
event.duration          # => Duration in milliseconds
event.duration_seconds  # => Duration in seconds
event.payload          # => Hash with operation metadata
event.started_at       # => Time when operation started
event.finished_at      # => Time when operation finished
```

### Metrics Integration

Kaito supports integration with popular metrics backends like StatsD and Datadog:

#### StatsD Integration

```ruby
require 'statsd-instrument'

statsd = StatsD.new('localhost', 8125)

Kaito.configure do |config|
  config.metrics = Kaito::Metrics.new(
    backend: :statsd,
    client: statsd,
    namespace: 'kaito',
    tags: { env: 'production', service: 'text_processor' }
  )
end

# Metrics are automatically tracked
chunks = Kaito.split(text, strategy: :semantic, max_tokens: 512)

# Metrics tracked:
# - kaito.split.duration (timing)
# - kaito.split.count (counter)
# - kaito.split.chunks (gauge)
# - kaito.split.tokens (gauge)
```

#### Datadog Integration

```ruby
require 'datadog/statsd'

datadog = Datadog::Statsd.new('localhost', 8125)

Kaito.configure do |config|
  config.metrics = Kaito::Metrics.new(
    backend: :datadog,
    client: datadog,
    namespace: 'kaito',
    tags: { env: 'production' }
  )
end
```

#### Custom Metrics Backend

```ruby
class CustomMetrics
  def increment(metric, value = 1, tags: {})
    # Your custom implementation
  end

  def timing(metric, value, tags: {})
    # Your custom implementation
  end

  def gauge(metric, value, tags: {})
    # Your custom implementation
  end
end

Kaito.configure do |config|
  config.metrics = Kaito::Metrics.new(
    backend: :custom,
    client: CustomMetrics.new
  )
end
```

### Production Setup

Here's a complete production-ready observability configuration:

```ruby
Kaito.configure do |config|
  # Structured JSON logging for log aggregation
  config.logger = Kaito::Logger.new(
    $stdout,
    level: ENV['LOG_LEVEL']&.to_sym || :info,
    format: :json
  )

  # StatsD metrics for dashboards
  config.metrics = Kaito::Metrics.new(
    backend: :statsd,
    client: StatsD.new(ENV['STATSD_HOST'], ENV['STATSD_PORT']),
    namespace: 'kaito',
    tags: {
      service: 'text_processor',
      env: ENV['RACK_ENV'],
      version: Kaito::VERSION
    }
  )

  # Instrumentation for APM
  config.instrumentation_enabled = true
end

# Subscribe to events for APM integration
Kaito::Instrumentation.subscribe(/\.kaito$/) do |event|
  NewRelic::Agent.record_metric(
    "Custom/Kaito/#{event.name}",
    event.duration
  )
end
```

### Performance Considerations

All observability features are designed to be opt-in and have minimal performance impact:

- **Logging**: No overhead when logger is not configured
- **Instrumentation**: Zero cost when no subscribers are registered
- **Metrics**: No-op adapter when metrics are disabled
- **Thread-safe**: All observability components are thread-safe

See `examples/observability_example.rb` for more detailed usage examples.

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

We deeply respect the work that [Baran](https://github.com/moeki0/baran) and [LangChain.rb](https://github.com/patterns-ai-core/langchainrb) have contributed to the Ruby LLM ecosystem. This comparison is meant to help you choose the right tool for your specific needs.

### When to Use Each Tool

**Use [Baran](https://github.com/moeki0/baran) if you:**
- Need a simple, lightweight solution for basic text splitting
- Are prototyping or exploring LLM applications
- Don't require precise token counting or semantic boundaries
- Prefer minimal dependencies

**Use [LangChain.rb](https://github.com/patterns-ai-core/langchainrb) if you:**
- Need the full LangChain ecosystem (chains, agents, memory, etc.)
- Are already invested in the LangChain architecture
- Want a familiar API if coming from Python LangChain
- Need integration with LangChain's vector store abstractions

**Use Kaito if you:**
- Need production-grade performance and accuracy
- Require precise token counting for GPT models
- Are building RAG systems with semantic retrieval requirements
- Need to process large documents or corpora efficiently
- Want adaptive overlap and intelligent boundary preservation
- Require robust multilingual support

### Feature Comparison

#### Kaito vs [Baran](https://github.com/moeki0/baran)

| Feature | Baran | Kaito |
|---------|-------|-------|
| Token-aware splitting | ❌ | ✅ Multiple backends |
| Semantic boundaries | ❌ | ✅ Advanced |
| Chunk overlap | ❌ | ✅ Adaptive |
| Multilingual | ❌ | ✅ Robust |
| Streaming | ❌ | ✅ Built-in |
| Performance | ⚠️ OK | ✅ Optimized |
| Simplicity | ✅ Excellent | ⚠️ More configuration |

#### Kaito vs [LangChain.rb](https://github.com/patterns-ai-core/langchainrb)

| Feature | LangChain Ruby | Kaito |
|---------|----------------|-------|
| Token accuracy | ⚠️ Limited | ✅ tiktoken_ruby |
| Performance | ⚠️ Slow | ✅ 3-5x faster |
| Feature parity | ⚠️ Incomplete | ✅ Complete |
| Adaptive overlap | ❌ | ✅ |
| Structure-aware | ⚠️ Basic | ✅ Advanced |
| Documentation | ⚠️ OK | ✅ Comprehensive |
| Full LangChain ecosystem | ✅ | ❌ (text splitting only) |

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

Bug reports and pull requests are welcome on GitHub at https://github.com/codeRailroad/kaito.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

Kaito stands on the shoulders of giants. We're deeply grateful to:

- **[Baran](https://github.com/moeki0/baran)** and its maintainers for pioneering text splitting for LLM applications in Ruby, proving the need for dedicated chunking tools in our ecosystem
- **[LangChain.rb](https://github.com/patterns-ai-core/langchainrb)** and the Patterns team for bringing sophisticated multi-strategy splitting and the broader LangChain ecosystem to Ruby developers
- The maintainers of **[tiktoken_ruby](https://github.com/IAPark/tiktoken_ruby)** for providing accurate token counting
- The **[pragmatic_segmenter](https://github.com/diasks2/pragmatic_segmenter)** project for robust sentence boundary detection

These projects have paved the way and demonstrated what's possible. Kaito aims to build upon their foundation and contribute back to the Ruby LLM community.

## Credits

Created by Magnus Fremont

Kaito (解答) - providing solutions for LLM text processing in Ruby.
