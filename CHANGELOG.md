# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-11-07

### Added

- Initial production release of Kaito
- **BREAKING**: Removed inaccurate Claude tokenizer support (use `:character` tokenizer for Claude models)
- Token-aware text splitting with tiktoken_ruby integration
- Multiple splitting strategies:
  - Character-based splitting
  - Semantic splitting with sentence boundary preservation
  - Structure-aware splitting for Markdown and code
  - Adaptive overlap with intelligent context preservation
  - Recursive splitting (LangChain-compatible)
- Support for multiple tokenizer backends (GPT-3.5, GPT-4, GPT-4 Turbo, Character)
- Streaming API for processing large files
- Configurable chunk overlap
- Comprehensive metadata tracking
- CLI tool with split, count, benchmark, and validate commands
- Multilingual support with Unicode normalization
- Test coverage for core splitting strategies
- Complete API documentation with YARD
- Performance optimizations for large documents

### Fixed

- AdaptiveOverlap splitter now properly enforces max_tokens constraint with overlap
- CLI FileUtils require added (fixes --output flag crash)

### Improved

- Comprehensive test coverage for CLI functionality (17 new tests)
- Complete test suite for StructureAware splitter (28 new tests)
- Test coverage increased from 50% to 85%+ (163 total tests)
- Added clear documentation of supported tokenizers
- Improved error messages for unsupported tokenizers
- Production-ready metadata and gemspec configuration

[0.1.0]: https://github.com/codeRailroad/kaito/releases/tag/v0.1.0
