# Kaito Architecture

This document provides a comprehensive overview of Kaito's architecture, component design, and splitting decision flow.

## Table of Contents

- [Overview](#overview)
- [High-Level Architecture](#high-level-architecture)
- [Core Components](#core-components)
- [Class Hierarchy](#class-hierarchy)
- [Splitting Decision Tree](#splitting-decision-tree)
- [Integration Points](#integration-points)
- [Data Flow](#data-flow)

## Overview

Kaito is designed as a modular, extensible text splitting library with clear separation of concerns. The architecture follows object-oriented design principles with a focus on:

- **Modularity**: Each component has a single, well-defined responsibility
- **Extensibility**: Easy to add new splitting strategies and tokenizers
- **Performance**: Optimized algorithms with streaming support
- **Observability**: Built-in logging, metrics, and instrumentation

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Kaito API                           │
│                    (Module-level methods)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌──────────────┐ ┌───────────┐ ┌──────────────┐
│ Configuration│ │ Splitters │ │  Tokenizers  │
│              │ │           │ │              │
│  - Defaults  │ │  - Base   │ │   - Base     │
│  - Logger    │ │  - Char   │ │   - Tiktoken │
│  - Metrics   │ │  - Sem    │ │   - Character│
│  - Instrum.  │ │  - Struct │ │              │
└──────────────┘ │  - Adapt  │ └──────────────┘
                 │  - Recur  │
                 └─────┬─────┘
                       │
                ┌──────┴──────┐
                │             │
                ▼             ▼
         ┌───────────┐  ┌──────────┐
         │   Chunk   │  │   Utils  │
         │           │  │          │
         │ - Text    │  │ TextUtils│
         │ - Tokens  │  └──────────┘
         │ - Metadata│
         └───────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Observability Layer                        │
│                                                              │
│  ┌──────────┐     ┌──────────────┐     ┌────────────┐     │
│  │  Logger  │     │Instrumentation│     │  Metrics   │     │
│  │          │────▶│               │────▶│            │     │
│  │ - Struct │     │  - Events     │     │ - StatsD   │     │
│  │ - JSON   │     │  - Subscribers│     │ - Datadog  │     │
│  └──────────┘     └──────────────┘     │ - Custom   │     │
│                                         └────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Kaito Module (Main Entry Point)

**Location**: `/lib/kaito.rb`

The main module provides a clean, simple API for users:

```ruby
Kaito.split(text, strategy: :semantic, max_tokens: 512)
Kaito.stream_file(path, max_tokens: 512)
Kaito.count_tokens(text, tokenizer: :gpt4)
Kaito.configure { |config| ... }
```

**Responsibilities**:
- Factory methods for creating splitters
- Factory methods for creating tokenizers
- Global configuration management
- Simple convenience methods

### 2. Configuration

**Location**: `/lib/kaito/configuration.rb`

Manages global defaults and settings:

```ruby
class Configuration
  attr_accessor :default_tokenizer      # Default: :gpt4
  attr_accessor :default_max_tokens     # Default: 512
  attr_accessor :default_overlap_tokens # Default: 0
  attr_accessor :default_strategy       # Default: :semantic
  attr_accessor :logger                 # Optional logger
  attr_accessor :metrics                # Optional metrics
  attr_accessor :instrumentation_enabled # Default: false
end
```

### 3. Splitters

**Location**: `/lib/kaito/splitters/`

All splitters inherit from `Splitters::Base` which provides:

- Common initialization and validation
- Token counting
- Overlap calculation
- File streaming
- Observability hooks

#### Base Splitter

```ruby
class Base
  attr_reader :max_tokens, :overlap_tokens, :tokenizer, :min_tokens

  def initialize(max_tokens:, overlap_tokens:, tokenizer:)
  def split(text) # Public interface with observability
  def perform_split(text) # Subclasses implement this
  def stream_file(file_path)
  def count_tokens(text)
end
```

#### Strategy Implementations

| Strategy | Best For | Key Features |
|----------|----------|--------------|
| **Character** | Simple, predictable splits | Binary search for exact token counts |
| **Semantic** | Natural text, preserves meaning | Sentence/paragraph boundary detection |
| **StructureAware** | Markdown, code | Respects headers, code blocks, lists |
| **AdaptiveOverlap** | RAG, context preservation | Similarity-based overlap calculation |
| **Recursive** | LangChain compatibility | Progressive separator hierarchy |

### 4. Tokenizers

**Location**: `/lib/kaito/tokenizers/`

#### Base Tokenizer

```ruby
class Base
  def count(text)      # Count tokens
  def encode(text)     # Text → token IDs
  def decode(tokens)   # Token IDs → text
  def truncate(text, max_tokens:) # Trim to fit
end
```

#### Implementations

- **Tiktoken**: Uses `tiktoken_ruby` for accurate GPT tokenization
  - Supports: `:gpt4`, `:gpt35_turbo`, `:gpt4_turbo`
  - Model mappings to tiktoken encodings

- **Character**: Simple approximation (4 chars ≈ 1 token)
  - Fast, no dependencies
  - Good for prototyping or non-GPT models

### 5. Chunk

**Location**: `/lib/kaito/chunk.rb`

Immutable data structure representing a text chunk:

```ruby
class Chunk
  attr_reader :text, :metadata, :token_count

  # Metadata may include:
  # - index: position in sequence
  # - start_offset, end_offset: byte positions
  # - source_file: file path
  # - structure: headers, levels
  # - overlap_tokens: overlap amount
  # - adaptive_overlap: boolean flag
end
```

### 6. Text Utils

**Location**: `/lib/kaito/utils/text_utils.rb`

Utility functions for text processing:

```ruby
module TextUtils
  def self.normalize(text)        # Unicode NFKC normalization
  def self.clean(text)            # Remove extra whitespace
  def self.simple_sentence_split(text) # Fallback sentence detection
  def self.split_paragraphs(text) # Split by double newlines
  def self.markdown?(text)        # Detect markdown
  def self.code?(text)           # Detect code
  def self.similarity(a, b)      # Jaccard similarity
  def self.find_overlap(a, b)    # Find overlapping text
end
```

### 7. Observability Components

#### Logger

**Location**: `/lib/kaito/logger.rb`

Structured logging with text and JSON formats:

```ruby
logger = Kaito::Logger.new($stdout, level: :info, format: :json)

# Automatically logs:
# - Text splits
# - Tokenization operations
# - File streaming
# - Errors
```

#### Instrumentation

**Location**: `/lib/kaito/instrumentation.rb`

Event-based instrumentation with subscribers:

```ruby
Kaito::Instrumentation.subscribe('text_split.kaito') do |event|
  # event.name, event.duration, event.payload
end

# Events:
# - text_split.kaito
# - tokenization.kaito
# - file_streaming.kaito
```

#### Metrics

**Location**: `/lib/kaito/metrics.rb`

Multi-backend metrics support:

```ruby
metrics = Kaito::Metrics.new(
  backend: :statsd,  # or :datadog, :custom, :null
  client: statsd_client
)

# Tracks:
# - split.duration, split.count, split.chunks, split.tokens
# - tokenization.duration, tokenization.count
# - streaming.duration, streaming.chunks
# - error.count
```

## Class Hierarchy

```
Kaito (Module)
├── Configuration
├── Chunk
├── Errors
│   ├── KaitoError < StandardError
│   ├── SplitterError < KaitoError
│   ├── TokenizerError < KaitoError
│   ├── FileError < KaitoError
│   └── ConfigurationError < KaitoError
├── Tokenizers (Module)
│   ├── Base (Abstract)
│   ├── Tiktoken < Base
│   └── Character < Base
├── Splitters (Module)
│   ├── Base (Abstract)
│   ├── Character < Base
│   ├── Semantic < Base
│   ├── StructureAware < Base
│   ├── AdaptiveOverlap < Base
│   └── Recursive < Base
├── Utils (Module)
│   └── TextUtils (Module)
├── Logger
├── Instrumentation
│   └── Event
├── Metrics
│   ├── StatsDAdapter
│   ├── DatadogAdapter
│   ├── CustomAdapter
│   └── NullAdapter
└── CLI < Thor

Dependencies:
- tiktoken_ruby (~> 0.0.6)
- pragmatic_segmenter (~> 0.3.23)
- unicode_utils (~> 1.4)
- thor (~> 1.3)
```

## Splitting Decision Tree

This flowchart shows how Kaito decides which approach to use for splitting text:

```
                    ┌──────────────┐
                    │  User Input  │
                    │  - text      │
                    │  - strategy  │
                    │  - options   │
                    └──────┬───────┘
                           │
                           ▼
                  ┌────────────────┐
                  │ Create Splitter│
                  │ Based on       │
                  │ Strategy Param │
                  └────────┬───────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
   :character         :semantic        :structure_aware
        │                  │                  │
        │                  ▼                  ▼
        │         ┌────────────────┐  ┌─────────────┐
        │         │ Preserve Para? │  │ Markdown?   │
        │         └───┬────────┬───┘  └──┬──────┬───┘
        │             │        │         │      │
        │           Yes       No        Yes    No
        │             │        │         │      │
        │             ▼        ▼         ▼      ▼
        │      Split by   Split by   Extract  Code?
        │      Paragraphs Sentences  Sections   │
        │             │        │         │    Yes/No
        │             └────┬───┘         │      │
        │                  │             │      ▼
        ▼                  ▼             ▼   Fallback to
   Binary Search    Use PragmaticSeg  Combine  Semantic
   for Exact        or fallback      Sections
   Token Count      to simple split
        │                  │             │
        └──────────────────┼─────────────┘
                           │
                           ▼
                  ┌────────────────┐
                  │ Combine into   │
                  │ Chunks         │
                  │ (max_tokens)   │
                  └────────┬───────┘
                           │
                           ▼
                  ┌────────────────┐
                  │ Add Overlap?   │
                  └───┬────────┬───┘
                      │        │
                     Yes      No
                      │        │
                      ▼        │
            ┌─────────────┐   │
            │ Calculate   │   │
            │ Overlap     │   │
            │ (static or  │   │
            │  adaptive)  │   │
            └──────┬──────┘   │
                   │          │
                   └────┬─────┘
                        │
                        ▼
                ┌───────────────┐
                │ Create Chunk  │
                │ Objects with  │
                │ Metadata      │
                └───────┬───────┘
                        │
                        ▼
                ┌───────────────┐
                │ Return Array  │
                │ of Chunks     │
                └───────────────┘
```

### Strategy Selection Guidelines

```
┌─────────────────────────────────────────────────┐
│           What are you splitting?               │
└───────────────────┬─────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
    Plain Text   Markdown    Code Files
        │           │           │
        │           └────┬──────┘
        │                │
        ▼                ▼
  Need semantic    :structure_aware
  boundaries?
        │
    ┌───┴───┐
    │       │
   Yes     No
    │       │
    ▼       ▼
:semantic  :character

┌─────────────────────────────────────────────────┐
│        What's your primary goal?                │
└───────────────────┬─────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
    Speed      Context      Compatibility
        │       Preservation      │
        │           │             │
        ▼           ▼             ▼
:character  :adaptive_overlap  :recursive
            (for RAG systems)  (LangChain)
```

## Integration Points

### 1. Tokenizer Integration

Kaito abstracts tokenization behind the `Tokenizers::Base` interface. To add a new tokenizer:

```ruby
class MyTokenizer < Kaito::Tokenizers::Base
  def count(text)
    # Your implementation
  end

  def encode(text)
    # Your implementation
  end

  def decode(tokens)
    # Your implementation
  end
end

# Usage
splitter = Kaito::Splitters::Semantic.new(
  tokenizer: MyTokenizer.new
)
```

### 2. Splitter Extension

To create a custom splitting strategy:

```ruby
class MySplitter < Kaito::Splitters::Base
  def perform_split(text)
    # Your implementation
    # Must return Array<Chunk>

    chunks = []
    # ... splitting logic ...

    chunks.map.with_index do |text, idx|
      Kaito::Chunk.new(
        text,
        metadata: { index: idx },
        token_count: tokenizer.count(text)
      )
    end
  end
end
```

### 3. Metrics Integration

```ruby
# Custom metrics backend
class MyMetrics
  def increment(metric, value = 1, tags: {}); end
  def timing(metric, value, tags: {}); end
  def gauge(metric, value, tags: {}); end
end

Kaito.configure do |config|
  config.metrics = Kaito::Metrics.new(
    backend: :custom,
    client: MyMetrics.new
  )
end
```

### 4. Logger Integration

```ruby
# Use your own logger
Kaito.configure do |config|
  config.logger = Kaito::Logger.new(
    Rails.logger,  # Or any Logger-compatible object
    level: :info,
    format: :json
  )
end
```

### 5. Instrumentation Integration

```ruby
# Subscribe to all events
Kaito::Instrumentation.subscribe do |event|
  # Send to APM
  NewRelic::Agent.record_metric(
    "Custom/Kaito/#{event.name}",
    event.duration
  )
end

# Subscribe to specific events
Kaito::Instrumentation.subscribe('text_split.kaito') do |event|
  # Custom handling
end
```

## Data Flow

### Typical Split Operation

```
1. User calls Kaito.split(text, options)
                    │
                    ▼
2. Factory creates splitter instance
   - Initializes tokenizer
   - Validates parameters
                    │
                    ▼
3. Splitter#split(text) called
   - Starts instrumentation (if enabled)
   - Logs operation start
                    │
                    ▼
4. Splitter#perform_split(text)
   - Strategy-specific logic
   - Uses tokenizer for counting
   - Uses TextUtils for parsing
                    │
                    ▼
5. Create Chunk objects
   - Text content
   - Token count
   - Metadata (index, offsets, etc.)
                    │
                    ▼
6. Add overlap (if configured)
   - Calculate overlap regions
   - Merge with next chunk
                    │
                    ▼
7. Observability hooks
   - Log completion
   - Track metrics
   - Emit instrumentation event
                    │
                    ▼
8. Return Array<Chunk>
```

### File Streaming Flow

```
1. User calls splitter.stream_file(path)
                    │
                    ▼
2. Create Enumerator
   - Open file for reading
   - Initialize buffer
                    │
                    ▼
3. Read file line by line
   - Accumulate in buffer
                    │
                    ▼
4. When buffer reaches threshold
   (2x max_tokens)
                    │
                    ▼
5. Split buffer content
   - Call perform_split
                    │
                    ▼
6. Yield chunks
   - One at a time
   - With file metadata
                    │
                    ▼
7. Keep last chunk as overlap
   - For continuity
                    │
                    ▼
8. Continue until EOF
                    │
                    ▼
9. Process remaining buffer
```

## Performance Considerations

### Binary Search Optimization

Both `Character` splitter and overlap calculation use binary search to find optimal split points. This reduces the complexity from O(n²) to O(n log n).

### Lazy Evaluation

File streaming uses Ruby Enumerators for lazy evaluation. Chunks are only created when requested, minimizing memory usage for large files.

### Caching

Tokenizer results can be cached at the configuration level to avoid redundant tokenization of repeated strings.

### Minimal String Copying

Splitters use string slicing views where possible to avoid unnecessary string copying until the final Chunk objects are created.

## Error Handling

Kaito has a clear error hierarchy:

```ruby
KaitoError (base)
├── SplitterError    # Splitting failures
├── TokenizerError   # Tokenization failures
├── FileError        # File I/O failures
└── ConfigurationError # Invalid configuration
```

All errors include:
- Descriptive messages
- Context about the operation
- Original error cause (when applicable)

Errors are logged through the observability layer before being raised.

## Thread Safety

All core components are designed to be thread-safe:

- **Splitters**: Stateless (can be shared across threads)
- **Tokenizers**: Use thread-safe underlying libraries
- **Configuration**: Frozen after initialization
- **Observability**: Thread-safe by design

However, file streaming should not share file handles across threads.

## Testing Architecture

Kaito uses RSpec with:

- **Unit tests**: For each component in isolation
- **Integration tests**: For realistic end-to-end scenarios
- **Coverage requirements**: 85% overall, 70% per file
- **Performance tests**: Benchmark critical paths

See `spec/` directory for test organization.
