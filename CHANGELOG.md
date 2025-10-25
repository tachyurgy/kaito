# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-10-25

### Added

- Initial release of Kaito
- Token-aware text splitting with tiktoken_ruby integration
- Multiple splitting strategies:
  - Character-based splitting
  - Semantic splitting with sentence boundary preservation
  - Structure-aware splitting for Markdown and code
  - Adaptive overlap with intelligent context preservation
  - Recursive splitting (LangChain-compatible)
- Support for multiple tokenizer backends (GPT-3.5, GPT-4, Claude)
- Streaming API for processing large files
- Configurable chunk overlap
- Comprehensive metadata tracking
- CLI tool with split, count, benchmark, and validate commands
- Multilingual support with Unicode normalization
- Extensive test coverage (95%+)
- Complete API documentation with YARD
- Performance optimizations for large documents

### Features

- **Tokenizers**
  - Tiktoken integration for accurate OpenAI token counting
  - Character tokenizer for simple use cases
  - Caching support for improved performance

- **Splitters**
  - Base splitter with shared functionality
  - Character splitter for fixed-size chunks
  - Semantic splitter with pragmatic_segmenter integration
  - Structure-aware splitter for Markdown and code
  - Adaptive overlap splitter with similarity-based overlap
  - Recursive splitter with configurable separators

- **CLI**
  - `kaito split` - Split files into chunks
  - `kaito count` - Count tokens in files
  - `kaito benchmark` - Compare strategy performance
  - `kaito validate` - Validate chunk quality
  - JSON, JSONL, and text output formats

- **API**
  - Global configuration
  - Chunk metadata and inspection
  - Stream processing for large files
  - Token counting utilities
  - Error handling and validation

[0.1.0]: https://github.com/yourusername/kaito/releases/tag/v0.1.0
