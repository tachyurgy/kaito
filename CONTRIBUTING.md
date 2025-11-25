# Contributing to Kaito

Thank you for your interest in contributing to Kaito! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Testing Guidelines](#testing-guidelines)
- [Code Style Guidelines](#code-style-guidelines)
- [Documentation Guidelines](#documentation-guidelines)
- [Pull Request Process](#pull-request-process)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow:

- **Be respectful**: Treat all contributors with respect and kindness
- **Be constructive**: Provide helpful feedback and suggestions
- **Be collaborative**: Work together to improve the project
- **Be inclusive**: Welcome contributors of all backgrounds and skill levels

## Getting Started

### Prerequisites

- Ruby >= 3.0.0
- Bundler
- Git

### Finding Issues to Work On

- Check the [GitHub Issues](https://github.com/codeRailroad/kaito/issues) for open issues
- Look for issues labeled `good first issue` for beginner-friendly tasks
- Look for issues labeled `help wanted` for areas where contributions are especially welcome
- Feel free to propose new features by opening an issue first

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/kaito.git
cd kaito
```

### 2. Install Dependencies

```bash
bundle install
```

This will install all required gems:
- `tiktoken_ruby` - Token counting for GPT models
- `pragmatic_segmenter` - Sentence boundary detection
- `unicode_utils` - Unicode text normalization
- `thor` - CLI framework
- Development dependencies (RSpec, Standard, SimpleCov, etc.)

### 3. Verify Installation

```bash
# Run tests to ensure everything works
bundle exec rspec

# Run linter
bundle exec standardrb

# Generate documentation
bundle exec yard doc
```

### 4. Set Up Git Hooks (Optional)

```bash
# Create pre-commit hook for linting
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
bundle exec standardrb
EOF

chmod +x .git/hooks/pre-commit
```

## Development Workflow

### Branch Strategy

- `main` - Stable, production-ready code
- Feature branches - `feature/your-feature-name`
- Bug fix branches - `fix/issue-description`
- Documentation branches - `docs/topic`

### Creating a Feature Branch

```bash
# Update main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/my-feature

# Make your changes
# ...

# Commit changes
git add .
git commit -m "Add feature: description"

# Push to your fork
git push origin feature/my-feature
```

### Commit Message Guidelines

Write clear, descriptive commit messages:

```
Add feature: brief description

Longer explanation of the change, why it was needed,
and what problem it solves.

Closes #123
```

**Format**:
- Use imperative mood ("Add feature" not "Added feature")
- First line: 50 characters or less
- Blank line after first line
- Detailed explanation if needed
- Reference related issues

**Good examples**:
```
Add semantic overlap calculation to AdaptiveOverlap splitter

Implement similarity-based overlap calculation using Jaccard
similarity. This improves context preservation for RAG systems
by intelligently determining which sentences to include in overlap
regions.

Closes #45
```

**Bad examples**:
```
fixed bug
update code
changes
```

## Testing Guidelines

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/kaito/splitters/semantic_spec.rb

# Run specific test
bundle exec rspec spec/kaito/splitters/semantic_spec.rb:42

# Run with coverage
bundle exec rake coverage
```

### Test Structure

Kaito uses RSpec for testing with the following structure:

```
spec/
├── spec_helper.rb              # Test configuration
├── kaito_spec.rb               # Module-level tests
├── kaito/
│   ├── chunk_spec.rb           # Chunk class tests
│   ├── configuration_spec.rb   # Configuration tests
│   ├── splitters/
│   │   ├── character_spec.rb
│   │   ├── semantic_spec.rb
│   │   └── ...
│   ├── tokenizers/
│   │   ├── tiktoken_spec.rb
│   │   └── character_spec.rb
│   ├── logger_spec.rb
│   ├── metrics_spec.rb
│   └── instrumentation_spec.rb
└── integration/
    └── real_world_scenarios_spec.rb
```

### Writing Tests

#### Unit Tests

Test individual components in isolation:

```ruby
RSpec.describe Kaito::Splitters::Semantic do
  describe '#split' do
    let(:splitter) do
      described_class.new(
        max_tokens: 100,
        tokenizer: :character
      )
    end

    context 'with simple text' do
      it 'splits by sentences' do
        text = "First sentence. Second sentence. Third sentence."
        chunks = splitter.split(text)

        expect(chunks.length).to be > 0
        expect(chunks.first).to be_a(Kaito::Chunk)
      end
    end

    context 'with empty text' do
      it 'returns empty array' do
        expect(splitter.split('')).to eq([])
        expect(splitter.split(nil)).to eq([])
      end
    end

    context 'with oversized sentences' do
      it 'falls back to character splitting' do
        text = 'a' * 500
        chunks = splitter.split(text)

        expect(chunks).not_to be_empty
        expect(chunks.all? { |c| c.token_count <= 100 }).to be true
      end
    end
  end
end
```

#### Integration Tests

Test realistic end-to-end scenarios:

```ruby
RSpec.describe 'Real world scenarios' do
  it 'processes a markdown document correctly' do
    markdown = File.read('spec/fixtures/sample.md')

    chunks = Kaito.split(
      markdown,
      strategy: :structure_aware,
      max_tokens: 512
    )

    expect(chunks).not_to be_empty
    expect(chunks.first.metadata[:structure]).to be_present
  end
end
```

### Test Coverage

- **Minimum overall coverage**: 85%
- **Minimum per-file coverage**: 70%
- Coverage is tracked with SimpleCov
- Coverage reports are generated in `coverage/`

### Testing Best Practices

1. **Test behavior, not implementation**
   ```ruby
   # Good
   expect(chunks.length).to eq(3)
   expect(chunks.first.text).to start_with('First')

   # Bad (testing internal state)
   expect(splitter.instance_variable_get(:@buffer)).to eq('...')
   ```

2. **Use descriptive test names**
   ```ruby
   # Good
   it 'preserves sentence boundaries when splitting'
   it 'handles empty input gracefully'

   # Bad
   it 'works'
   it 'test1'
   ```

3. **Test edge cases**
   - Empty input
   - Very large input
   - Special characters
   - Unicode text
   - Nil values

4. **Use fixtures for complex test data**
   ```ruby
   # spec/fixtures/sample.md
   let(:text) { File.read('spec/fixtures/sample.md') }
   ```

5. **Keep tests isolated**
   - Don't depend on order of execution
   - Clean up after tests (if needed)
   - Use `let` for test data

## Code Style Guidelines

Kaito uses [StandardRB](https://github.com/testdouble/standard) for Ruby style enforcement.

### Running the Linter

```bash
# Check for style issues
bundle exec standardrb

# Auto-fix issues
bundle exec standardrb --fix
```

### Key Style Rules

#### 1. String Literals

Use single quotes unless interpolation is needed:

```ruby
# Good
'Hello world'
"Hello #{name}"

# Bad
"Hello world"
```

#### 2. Method Definitions

```ruby
# Good
def method_name(param1, param2)
  # code
end

# Bad
def method_name( param1, param2 )
  # code
end
```

#### 3. Conditional Statements

```ruby
# Good
if condition
  do_something
end

return if early_return_condition

# Bad
if condition then do_something end
```

#### 4. String Freezing

Use frozen string literals:

```ruby
# At the top of every file
# frozen_string_literal: true
```

#### 5. Line Length

- Maximum 120 characters per line
- Break long lines logically:

```ruby
# Good
splitter = Kaito::Splitters::Semantic.new(
  max_tokens: 512,
  overlap_tokens: 50,
  tokenizer: :gpt4
)

# Bad
splitter = Kaito::Splitters::Semantic.new(max_tokens: 512, overlap_tokens: 50, tokenizer: :gpt4)
```

#### 6. Method Complexity

Keep methods focused and concise:
- Maximum 20 lines per method (guideline, not rule)
- Extract complex logic into private methods
- Single Responsibility Principle

#### 7. Comments

```ruby
# Good - explain WHY, not WHAT
# Calculate overlap using binary search for performance
def calculate_overlap(text)
  # ...
end

# Bad - obvious comment
# Loops through chunks
chunks.each do |chunk|
  # ...
end
```

## Documentation Guidelines

### YARD Documentation

All public APIs must have YARD documentation:

```ruby
# Split text into chunks with overlap
#
# @param text [String] the text to split
# @param max_tokens [Integer] maximum tokens per chunk
# @param overlap_tokens [Integer] tokens to overlap between chunks
# @return [Array<Chunk>] array of text chunks
# @raise [ArgumentError] if max_tokens is invalid
#
# @example Basic usage
#   chunks = splitter.split(text, max_tokens: 512)
#
# @example With overlap
#   chunks = splitter.split(text, max_tokens: 512, overlap_tokens: 50)
def split(text, max_tokens: 512, overlap_tokens: 0)
  # ...
end
```

### Documentation Requirements

- **Classes**: Description, example usage
- **Methods**: Parameters, return values, exceptions
- **Constants**: Purpose and usage
- **Examples**: Include realistic examples

### Generating Documentation

```bash
# Generate YARD docs
bundle exec yard doc

# View documentation
open doc/index.html

# Check coverage
bundle exec yard stats
```

### README Updates

When adding features:
1. Update the main README.md
2. Add examples
3. Update the feature list
4. Update the table of contents if needed

## Pull Request Process

### 1. Before Submitting

- [ ] All tests pass (`bundle exec rspec`)
- [ ] Code follows style guidelines (`bundle exec standardrb`)
- [ ] New code has tests (coverage >= 85%)
- [ ] Public APIs have YARD documentation
- [ ] README updated if adding features
- [ ] CHANGELOG.md updated

### 2. Creating the Pull Request

1. Push your branch to your fork
2. Go to the original repository on GitHub
3. Click "New Pull Request"
4. Select your fork and branch
5. Fill in the PR template:

```markdown
## Description
Brief description of changes

## Motivation
Why is this change needed?

## Changes Made
- Item 1
- Item 2

## Testing
How was this tested?

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Changelog updated
- [ ] Code style checked
```

### 3. PR Review Process

- Maintainers will review your PR
- Address any requested changes
- Keep the discussion focused and professional
- Be patient - reviews may take a few days

### 4. After Approval

Once approved and merged:
- Your changes will be included in the next release
- You'll be added to the contributors list
- Delete your feature branch

## Release Process

(For maintainers)

### Version Numbering

Kaito follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

### Release Steps

1. **Update version** in `lib/kaito/version.rb`
2. **Update CHANGELOG.md** with release notes
3. **Run full test suite**
   ```bash
   bundle exec rspec
   bundle exec standardrb
   bundle exec yard doc
   ```
4. **Commit version bump**
   ```bash
   git add .
   git commit -m "Bump version to X.Y.Z"
   ```
5. **Create git tag**
   ```bash
   git tag -a vX.Y.Z -m "Release version X.Y.Z"
   git push origin main --tags
   ```
6. **Build and publish gem**
   ```bash
   gem build kaito.gemspec
   gem push kaito-X.Y.Z.gem
   ```
7. **Create GitHub release**
   - Go to GitHub Releases
   - Create new release from tag
   - Copy changelog entry
   - Publish release

## Development Tips

### Debugging

```ruby
# Use binding.pry for debugging (add to Gemfile.development)
require 'pry'

def my_method
  binding.pry  # Debugger will stop here
  # ...
end
```

### Performance Testing

```ruby
require 'benchmark'

# Benchmark your changes
text = File.read('large_file.txt')
time = Benchmark.realtime do
  chunks = splitter.split(text)
end

puts "Processed in #{time} seconds"
```

### Testing Locally

```ruby
# Test your changes in a local console
bundle exec irb -r ./lib/kaito

# Or create a test script
# test.rb
require_relative 'lib/kaito'

text = "Your test text here"
chunks = Kaito.split(text, strategy: :semantic, max_tokens: 512)
puts "Created #{chunks.length} chunks"
```

## Getting Help

- **Issues**: Open an issue for bugs or questions
- **Discussions**: Use GitHub Discussions for general questions
- **Email**: magnusfremont@proton.me

## Recognition

Contributors are recognized in:
- GitHub contributors page
- CHANGELOG.md (for significant contributions)
- README.md acknowledgments section

Thank you for contributing to Kaito!
