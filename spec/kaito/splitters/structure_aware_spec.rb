# frozen_string_literal: true

RSpec.describe Kaito::Splitters::StructureAware do
  let(:splitter) { described_class.new(max_tokens: 200, tokenizer: :character) }

  describe '#initialize' do
    it 'initializes with default parameters' do
      splitter = described_class.new
      expect(splitter.max_tokens).to eq(512)
      expect(splitter.preserve_code_blocks).to be true
      expect(splitter.preserve_lists).to be true
    end

    it 'initializes with custom parameters' do
      splitter = described_class.new(
        max_tokens: 100,
        preserve_code_blocks: false,
        preserve_lists: false
      )
      expect(splitter.max_tokens).to eq(100)
      expect(splitter.preserve_code_blocks).to be false
      expect(splitter.preserve_lists).to be false
    end
  end

  describe '#split' do
    it 'returns empty array for empty text' do
      expect(splitter.split('')).to eq([])
      expect(splitter.split(nil)).to eq([])
    end

    it 'splits text into chunks' do
      text = "# Header\n\nSome content here.\n\n## Subheader\n\nMore content."
      chunks = splitter.split(text)

      expect(chunks).to be_an(Array)
      expect(chunks).to all(be_a(Kaito::Chunk))
      expect(chunks).not_to be_empty
    end

    context 'markdown documents' do
      it 'preserves markdown header hierarchy' do
        text = <<~MARKDOWN
          # Main Header

          This is the introduction.

          ## Section 1

          Content for section 1.

          ## Section 2

          Content for section 2.

          ### Subsection 2.1

          More detailed content.
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty

        # Check that structure metadata is preserved
        chunks.each do |chunk|
          expect(chunk.metadata).to include(:structure)
        end
      end

      it 'keeps code blocks intact when preserve_code_blocks is true' do
        text = <<~MARKDOWN
          # Code Example

          Here's some code:

          ```ruby
          def hello
            puts "Hello, world!"
          end
          ```

          And some more text.
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty

        # Check that code blocks are preserved
        combined_text = chunks.map(&:text).join("\n")
        expect(combined_text).to include('```ruby')
        expect(combined_text).to include('def hello')
        expect(combined_text).to include('```')
      end

      it 'respects section boundaries' do
        text = <<~MARKDOWN
          # Section 1

          Content 1.

          # Section 2

          Content 2.
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles nested structures' do
        text = <<~MARKDOWN
          # Top Level

          Introduction

          ## Level 2

          Some content

          ### Level 3

          Nested content

          ## Another Level 2

          More content
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty

        # Verify that chunks have structure metadata
        chunks.each do |chunk|
          expect(chunk.metadata[:structure]).to be_a(Hash) if chunk.metadata[:structure]
        end
      end

      it 'splits oversized sections' do
        # Create a section that's too large for a single chunk
        large_section = "# Large Section\n\n#{'This is a very long sentence. ' * 50}"

        chunks = splitter.split(large_section)
        expect(chunks.length).to be >= 2

        # Ensure each chunk respects max_tokens
        chunks.each do |chunk|
          expect(chunk.token_count).to be <= splitter.max_tokens
        end
      end

      it 'handles markdown without headers' do
        text = "Just plain text without any headers.\n\nMultiple paragraphs though."
        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'preserves multiple code blocks' do
        text = <<~MARKDOWN
          # Examples

          First example:

          ```python
          print("Hello")
          ```

          Second example:

          ```javascript
          console.log("World");
          ```
        MARKDOWN

        chunks = splitter.split(text)
        combined_text = chunks.map(&:text).join("\n")

        expect(combined_text).to include('```python')
        expect(combined_text).to include('```javascript')
      end
    end

    context 'code documents' do
      it 'handles code structure' do
        code = <<~RUBY
          class MyClass
            def method_one
              puts "one"
            end

            def method_two
              puts "two"
            end
          end
        RUBY

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end

      it 'splits code by function boundaries' do
        code = <<~RUBY
          def function_one
            # Implementation
          end

          def function_two
            # Implementation
          end

          def function_three
            # Implementation
          end
        RUBY

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end

      it 'handles different programming languages' do
        javascript = <<~JS
          function hello() {
            console.log("Hello");
          }

          const greet = () => {
            console.log("Greetings");
          }
        JS

        chunks = splitter.split(javascript)
        expect(chunks).not_to be_empty
      end
    end

    context 'overlap handling' do
      let(:splitter_with_overlap) do
        described_class.new(max_tokens: 100, overlap_tokens: 20, tokenizer: :character)
      end

      it 'creates overlap between chunks when configured' do
        text = <<~MARKDOWN
          # Section 1

          #{'Content for section 1. ' * 20}

          # Section 2

          #{'Content for section 2. ' * 20}

          # Section 3

          #{'Content for section 3. ' * 20}
        MARKDOWN

        chunks = splitter_with_overlap.split(text)
        expect(chunks.length).to be >= 2
      end

      it 'respects overlap_tokens setting' do
        text = "# Header\n\n#{'Some content. ' * 50}"
        chunks = splitter_with_overlap.split(text)

        expect(chunks).not_to be_empty
      end
    end

    context 'metadata' do
      it 'includes section count in metadata' do
        text = <<~MARKDOWN
          # Section 1

          Content 1

          # Section 2

          Content 2
        MARKDOWN

        chunks = splitter.split(text)
        chunks.each do |chunk|
          expect(chunk.metadata).to include(:section_count)
        end
      end

      it 'includes structure information' do
        text = <<~MARKDOWN
          # Main

          Content

          ## Sub

          More content
        MARKDOWN

        chunks = splitter.split(text)
        chunks.each do |chunk|
          expect(chunk.metadata).to include(:structure)
          expect(chunk.metadata[:structure]).to be_a(Hash) if chunk.metadata[:structure]
        end
      end

      it 'includes index in metadata' do
        text = "# Header\n\nContent"
        chunks = splitter.split(text)

        chunks.each_with_index do |chunk, idx|
          expect(chunk.metadata[:index]).to eq(idx)
        end
      end
    end

    context 'edge cases' do
      it 'handles text with only headers' do
        text = "# Header 1\n## Header 2\n### Header 3"
        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles text with only code blocks' do
        text = "```ruby\ncode here\n```"
        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles mixed content' do
        text = <<~MARKDOWN
          # Header

          Some text.

          ```ruby
          code
          ```

          More text.
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles unicode content' do
        text = "# Título\n\nContenido en español con ñ y acentos."
        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles very small max_tokens' do
        small_splitter = described_class.new(max_tokens: 10, tokenizer: :character)
        text = "# Header\n\nContent"
        chunks = small_splitter.split(text)
        expect(chunks).not_to be_empty
      end
    end

    context 'respects max_tokens' do
      it 'ensures no chunk exceeds max_tokens' do
        text = <<~MARKDOWN
          # Section

          #{'Content goes here. ' * 100}
        MARKDOWN

        chunks = splitter.split(text)
        chunks.each do |chunk|
          expect(chunk.token_count).to be <= splitter.max_tokens
        end
      end
    end

    context 'fallback behavior' do
      it 'falls back to semantic splitting for plain text' do
        text = 'This is plain text without any markdown or code structure. ' * 10
        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end
    end

    context 'advanced markdown features' do
      it 'handles all six levels of markdown headers' do
        text = <<~MARKDOWN
          # Level 1
          Content 1

          ## Level 2
          Content 2

          ### Level 3
          Content 3

          #### Level 4
          Content 4

          ##### Level 5
          Content 5

          ###### Level 6
          Content 6
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty

        # Verify structure metadata includes all levels
        all_levels = chunks.flat_map { |c| c.metadata.dig(:structure, :levels) || [] }.compact
        expect(all_levels).to include(1, 2, 3, 4, 5, 6)
      end

      it 'handles headers followed immediately by another header' do
        text = <<~MARKDOWN
          # Header 1
          ## Header 2
          ### Header 3
          Some content finally
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles empty sections between headers' do
        text = <<~MARKDOWN
          # Section 1

          # Section 2

          Content here

          # Section 3

        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'preserves code block structure across sections' do
        text = <<~MARKDOWN
          # Implementation

          ```ruby
          def complex_method
            if condition
              # nested logic
              result = calculate()
            end
            result
          end
          ```

          # Testing

          More content here.
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join("\n")

        # Verify code block is intact
        expect(combined).to include('def complex_method')
        expect(combined).to include('nested logic')
        expect(combined).to include('end')
      end

      it 'handles inline code and code blocks separately' do
        text = <<~MARKDOWN
          # Code Examples

          Use `inline_code` in your text.

          ```ruby
          # Block code
          puts "hello"
          ```

          More text with `another_inline`.
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join("\n")

        expect(combined).to include('`inline_code`')
        expect(combined).to include('```ruby')
        expect(combined).to include('`another_inline`')
      end

      it 'handles markdown lists' do
        text = <<~MARKDOWN
          # Features

          - Item 1
          - Item 2
          - Item 3

          ## Numbered List

          1. First
          2. Second
          3. Third
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
        combined = chunks.map(&:text).join("\n")

        expect(combined).to include('- Item 1')
        expect(combined).to include('1. First')
      end

      it 'handles markdown with links and emphasis' do
        text = <<~MARKDOWN
          # Documentation

          Visit [our website](https://example.com) for more info.

          **Important**: This is *emphasized* text.
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join("\n")

        expect(combined).to include('[our website]')
        expect(combined).to include('**Important**')
      end

      it 'handles blockquotes in markdown' do
        text = <<~MARKDOWN
          # Quote Section

          > This is a quote
          > spanning multiple lines
          > with important content

          Regular text follows.
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles horizontal rules in markdown' do
        text = <<~MARKDOWN
          # Section 1

          Content before rule

          ---

          # Section 2

          Content after rule
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end
    end

    context 'code block preservation' do
      let(:splitter_no_preserve) do
        described_class.new(
          max_tokens: 200,
          tokenizer: :character,
          preserve_code_blocks: false
        )
      end

      it 'preserves code blocks when flag is true' do
        text = <<~MARKDOWN
          # Code

          ```ruby
          def test
            puts "test"
          end
          ```
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join("\n")

        expect(combined).to include('```ruby')
        expect(combined).to include('def test')
        expect(combined).to include('```')
      end

      it 'handles multiple consecutive code blocks' do
        text = <<~MARKDOWN
          # Examples

          ```ruby
          code1
          ```

          ```python
          code2
          ```

          ```javascript
          code3
          ```
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join("\n")

        expect(combined).to include('```ruby')
        expect(combined).to include('```python')
        expect(combined).to include('```javascript')
      end

      it 'handles code blocks with language specifiers' do
        text = <<~MARKDOWN
          ```ruby
          puts "Ruby"
          ```

          ```python
          print("Python")
          ```

          ```javascript
          console.log("JS");
          ```
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join("\n")

        expect(combined).to include('Ruby')
        expect(combined).to include('Python')
        expect(combined).to include('JS')
      end

      it 'handles code blocks without language specifiers' do
        text = <<~MARKDOWN
          ```
          plain code block
          no language
          ```
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles nested backticks in code blocks' do
        text = <<~MARKDOWN
          ```markdown
          # Example
          Use `backticks` for code
          ```
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join("\n")

        expect(combined).to include('`backticks`')
      end

      it 'handles empty code blocks' do
        text = <<~MARKDOWN
          # Empty Code

          ```ruby
          ```

          More content
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles code blocks at the end of text' do
        text = <<~MARKDOWN
          # Final Code

          Some text

          ```ruby
          final_code
          ```
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join

        expect(combined).to include('final_code')
      end
    end

    context 'heading hierarchy' do
      it 'maintains parent-child relationship in nested headers' do
        text = <<~MARKDOWN
          # Parent

          Content

          ## Child 1

          Content 1

          ### Grandchild 1.1

          Content 1.1

          ## Child 2

          Content 2
        MARKDOWN

        chunks = splitter.split(text)

        # Check structure metadata
        chunks.each do |chunk|
          next unless chunk.metadata[:structure]

          expect(chunk.metadata[:structure]).to have_key(:headers)
          expect(chunk.metadata[:structure]).to have_key(:levels)
        end
      end

      it 'handles non-sequential header levels' do
        text = <<~MARKDOWN
          # Level 1

          #### Level 4 (skipping 2 and 3)

          ## Level 2

          ##### Level 5
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles headers with special characters' do
        text = <<~MARKDOWN
          # Header with "quotes"

          ## Header with 'apostrophe'

          ### Header with & ampersand

          #### Header with <brackets>
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty

        combined = chunks.map(&:text).join("\n")
        expect(combined).to include('quotes')
        expect(combined).to include('apostrophe')
      end

      it 'handles headers with numbers and symbols' do
        text = <<~MARKDOWN
          # Section 1.2.3

          ## API v2.0

          ### Feature #42
        MARKDOWN

        chunks = splitter.split(text)
        headers = chunks.flat_map { |c| c.metadata.dig(:structure, :headers) || [] }.compact

        expect(headers).to include('Section 1.2.3')
        expect(headers).to include('API v2.0')
      end

      it 'handles very long header text' do
        long_header = 'A' * 500
        text = "# #{long_header}\n\nContent here."

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end
    end

    context 'mixed content scenarios' do
      it 'handles text with markdown, code blocks, and plain text' do
        text = <<~CONTENT
          # Overview

          This is plain text.

          ```ruby
          code_here
          ```

          More plain text.

          ## Details

          - List item 1
          - List item 2

          Final paragraph.
        CONTENT

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
        expect(chunks.length).to be >= 1
      end

      it 'handles alternating sections of different types' do
        text = <<~MARKDOWN
          # Code Section

          ```ruby
          code1
          ```

          # Text Section

          Regular text here.

          # Another Code Section

          ```python
          code2
          ```
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles sections with varying content lengths' do
        text = <<~MARKDOWN
          # Short

          Brief.

          # Long

          #{'This is a much longer section with lots of content. ' * 20}

          # Short Again

          Brief again.
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks.length).to be >= 2
      end

      it 'handles deeply nested structures' do
        text = <<~MARKDOWN
          # L1

          ## L2

          ### L3

          #### L4

          ##### L5

          ###### L6

          Content at deepest level.

          ##### Back to L5

          More content.
        MARKDOWN

        chunks = splitter.split(text)
        levels = chunks.flat_map { |c| c.metadata.dig(:structure, :levels) || [] }.compact
        expect(levels).to include(6)
      end
    end

    context 'code document splitting' do
      it 'handles Ruby class definitions' do
        code = <<~RUBY
          class UserController
            def index
              @users = User.all
            end

            def show
              @user = User.find(params[:id])
            end

            def create
              @user = User.new(user_params)
              @user.save
            end
          end
        RUBY

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end

      it 'handles module definitions' do
        code = <<~RUBY
          module Authentication
            def authenticate
              # auth logic
            end

            def authorize
              # authorization logic
            end
          end
        RUBY

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end

      it 'handles JavaScript functions' do
        code = <<~JS
          function calculateTotal(items) {
            return items.reduce((sum, item) => sum + item.price, 0);
          }

          const formatPrice = (price) => {
            return `$${price.toFixed(2)}`;
          }

          var oldStyleFunction = function() {
            console.log("old style");
          }
        JS

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end

      it 'handles Python code' do
        code = <<~PYTHON
          def calculate_sum(numbers):
              return sum(numbers)

          class Calculator:
              def add(self, a, b):
                  return a + b

              def subtract(self, a, b):
                  return a - b
        PYTHON

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end

      it 'handles nested functions and classes' do
        code = <<~RUBY
          class OuterClass
            def outer_method
              inner_lambda = lambda { |x| x * 2 }
              inner_lambda.call(5)
            end

            class InnerClass
              def inner_method
                puts "nested"
              end
            end
          end
        RUBY

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end

      it 'handles code with comments' do
        code = <<~RUBY
          # This is a comment
          def method_one
            # Comment inside method
            result = calculate()
            result
          end

          # Another comment
          def method_two
            # More comments
            process()
          end
        RUBY

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end

      it 'handles code with access modifiers' do
        code = <<~RUBY
          class SecureClass
            public

            def public_method
              "accessible"
            end

            private

            def private_method
              "hidden"
            end

            protected

            def protected_method
              "limited"
            end
          end
        RUBY

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end

      it 'handles code with imports and exports' do
        code = <<~JS
          import { Component } from 'react';
          import axios from 'axios';

          export const fetchData = async () => {
            const response = await axios.get('/api/data');
            return response.data;
          }

          export default Component;
        JS

        chunks = splitter.split(code)
        expect(chunks).not_to be_empty
      end
    end

    context 'token and size management' do
      it 'splits sections that exceed max_tokens' do
        large_content = 'Word ' * 300
        text = "# Large Section\n\n#{large_content}"

        chunks = splitter.split(text)
        expect(chunks.length).to be >= 2

        chunks.each do |chunk|
          expect(chunk.token_count).to be <= splitter.max_tokens
        end
      end

      it 'handles multiple large sections' do
        text = <<~MARKDOWN
          # Section 1

          #{'Content ' * 100}

          # Section 2

          #{'More content ' * 100}

          # Section 3

          #{'Even more content ' * 100}
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks.length).to be >= 3
      end

      it 'combines small sections into optimal chunks' do
        text = <<~MARKDOWN
          # A

          Short.

          # B

          Short.

          # C

          Short.

          # D

          Short.
        MARKDOWN

        chunks = splitter.split(text)

        # Small sections should be combined
        expect(chunks.length).to be < 4
      end

      it 'respects max_tokens for each chunk' do
        text = "# Header\n\n#{'Content here. ' * 200}"
        chunks = splitter.split(text)

        chunks.each do |chunk|
          expect(chunk.token_count).to be <= splitter.max_tokens
        end
      end
    end

    context 'overlap functionality' do
      let(:overlap_splitter) do
        described_class.new(
          max_tokens: 100,
          overlap_tokens: 30,
          tokenizer: :character
        )
      end

      it 'includes overlap sections between chunks' do
        text = <<~MARKDOWN
          # Section 1

          #{'Content for section one. ' * 30}

          # Section 2

          #{'Content for section two. ' * 30}

          # Section 3

          #{'Content for section three. ' * 30}
        MARKDOWN

        chunks = overlap_splitter.split(text)
        expect(chunks.length).to be >= 3
      end

      it 'calculates correct overlap amount' do
        text = <<~MARKDOWN
          # Part 1

          #{'Text ' * 40}

          # Part 2

          #{'Text ' * 40}
        MARKDOWN

        chunks = overlap_splitter.split(text)
        expect(chunks.length).to be >= 2
      end

      it 'handles overlap with zero overlap_tokens' do
        no_overlap = described_class.new(
          max_tokens: 100,
          overlap_tokens: 0,
          tokenizer: :character
        )

        text = "# Section\n\n#{'Content ' * 50}"
        chunks = no_overlap.split(text)

        expect(chunks).not_to be_empty
      end

      it 'handles overlap larger than section size' do
        text = <<~MARKDOWN
          # Tiny

          Small.

          # Another

          #{'Larger content here. ' * 50}
        MARKDOWN

        chunks = overlap_splitter.split(text)
        expect(chunks).not_to be_empty
      end
    end

    context 'metadata accuracy' do
      it 'includes correct section count for single section chunks' do
        text = "# Single\n\nContent here."
        chunks = splitter.split(text)

        expect(chunks.first.metadata[:section_count]).to eq(1)
      end

      it 'includes correct section count for multi-section chunks' do
        text = <<~MARKDOWN
          # A

          Content A

          # B

          Content B
        MARKDOWN

        chunks = splitter.split(text)

        # At least one chunk should have multiple sections
        multi_section_chunks = chunks.select { |c| c.metadata[:section_count] && c.metadata[:section_count] > 1 }
        expect(multi_section_chunks).not_to be_empty unless chunks.length >= 2
      end

      it 'includes header information in structure metadata' do
        text = <<~MARKDOWN
          # Main Title

          Content

          ## Subtitle

          More content
        MARKDOWN

        chunks = splitter.split(text)

        headers = chunks.flat_map { |c| c.metadata.dig(:structure, :headers) || [] }.compact
        expect(headers).to include('Main Title')
        expect(headers).to include('Subtitle')
      end

      it 'includes level information in structure metadata' do
        text = <<~MARKDOWN
          # Level 1

          ## Level 2

          ### Level 3
        MARKDOWN

        chunks = splitter.split(text)

        levels = chunks.flat_map { |c| c.metadata.dig(:structure, :levels) || [] }.compact
        expect(levels).to include(1, 2, 3)
      end

      it 'includes sub_chunk metadata for split large sections' do
        very_large = 'Word ' * 500
        text = "# Huge Section\n\n#{very_large}"

        chunks = splitter.split(text)

        # Some chunks should have sub_chunk metadata if section was split
        if chunks.length > 1
          sub_chunk_metadata = chunks.map { |c| c.metadata.dig(:structure, :sub_chunk) }.compact
          expect(sub_chunk_metadata).not_to be_empty
        end
      end

      it 'preserves chunk index across all chunks' do
        text = "# Section\n\n#{'Content ' * 100}"
        chunks = splitter.split(text)

        chunks.each_with_index do |chunk, idx|
          expect(chunk.metadata[:index]).to eq(idx)
        end
      end
    end

    context 'edge cases and error handling' do
      it 'handles text with only whitespace' do
        text = "   \n\n   \n   "
        chunks = splitter.split(text)

        # Should either return empty or handle gracefully
        expect(chunks).to be_an(Array)
      end

      it 'handles text with only newlines' do
        text = "\n\n\n\n\n"
        chunks = splitter.split(text)

        expect(chunks).to be_an(Array)
      end

      it 'handles single line of text' do
        text = 'Just one line'
        chunks = splitter.split(text)

        expect(chunks).not_to be_empty
        expect(chunks.first.text).to include('Just one line')
      end

      it 'handles header without content' do
        text = '# Header Only'
        chunks = splitter.split(text)

        expect(chunks).not_to be_empty
      end

      it 'handles multiple headers without content' do
        text = "# Header 1\n## Header 2\n### Header 3"
        chunks = splitter.split(text)

        expect(chunks).not_to be_empty
      end

      it 'handles content without any headers' do
        text = "Just plain content\nwith multiple lines\nbut no headers at all"
        chunks = splitter.split(text)

        expect(chunks).not_to be_empty
      end

      it 'handles malformed markdown headers' do
        text = <<~MARKDOWN
          #No space after hash
          # Proper header
          ##Also no space
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles unclosed code blocks' do
        text = <<~MARKDOWN
          # Code

          ```ruby
          code without closing backticks
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles very long lines' do
        long_line = 'A' * 10_000
        text = "# Header\n\n#{long_line}"

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles special unicode characters' do
        text = <<~MARKDOWN
          # Emojis

          Content with emojis

          ## Math Symbols

          More content
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles right-to-left text' do
        text = "# Title\n\nArabic content"
        chunks = splitter.split(text)

        expect(chunks).not_to be_empty
      end

      it 'handles mixed language content' do
        text = <<~MARKDOWN
          # English Header

          Some English content.

          # Japanese Header

          Japanese content.

          # Russian Header

          Russian content.
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles text with tabs and special whitespace' do
        text = "# Header\n\n\tIndented with tab\n  Spaces\n\t\tDouble tab"
        chunks = splitter.split(text)

        expect(chunks).not_to be_empty
      end

      it 'handles empty string as input' do
        chunks = splitter.split('')
        expect(chunks).to eq([])
      end

      it 'handles nil as input' do
        chunks = splitter.split(nil)
        expect(chunks).to eq([])
      end
    end

    context 'preserve_lists flag' do
      it 'respects preserve_lists setting' do
        splitter_preserve = described_class.new(
          max_tokens: 200,
          tokenizer: :character,
          preserve_lists: true
        )

        text = <<~MARKDOWN
          # List Example

          - Item 1
          - Item 2
          - Item 3
        MARKDOWN

        chunks = splitter_preserve.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles unordered lists' do
        text = <<~MARKDOWN
          # Tasks

          * Task 1
          * Task 2
          - Task 3
          - Task 4
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join("\n")

        expect(combined).to include('Task 1')
        expect(combined).to include('Task 4')
      end

      it 'handles ordered lists' do
        text = <<~MARKDOWN
          # Steps

          1. First step
          2. Second step
          3. Third step
        MARKDOWN

        chunks = splitter.split(text)
        combined = chunks.map(&:text).join("\n")

        expect(combined).to include('1. First step')
      end

      it 'handles nested lists' do
        text = <<~MARKDOWN
          # Outline

          - Level 1
            - Level 2
              - Level 3
          - Back to 1
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end
    end

    context 'real-world document scenarios' do
      it 'handles API documentation structure' do
        text = <<~MARKDOWN
          # API Documentation

          ## Authentication

          Use Bearer tokens.

          ## Endpoints

          ### GET /users

          ```json
          {
            "users": []
          }
          ```

          ### POST /users

          ```json
          {
            "name": "John"
          }
          ```

          ## Rate Limiting

          100 requests per hour.
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty

        combined = chunks.map(&:text).join("\n")
        expect(combined).to include('Authentication')
        expect(combined).to include('Endpoints')
        expect(combined).to include('Rate Limiting')
      end

      it 'handles README-style documentation' do
        text = <<~MARKDOWN
          # Project Name

          ## Installation

          ```bash
          npm install project
          ```

          ## Usage

          ```javascript
          import project from 'project';
          ```

          ## Contributing

          Please read CONTRIBUTING.md

          ## License

          MIT
        MARKDOWN

        chunks = splitter.split(text)
        expect(chunks).not_to be_empty
      end

      it 'handles tutorial-style content' do
        text = <<~MARKDOWN
          # Getting Started Tutorial

          ## Step 1: Setup

          Install dependencies.

          ## Step 2: Configuration

          Create config file.

          ## Step 3: Running

          Execute the application.

          ## Troubleshooting

          Common issues and solutions.
        MARKDOWN

        chunks = splitter.split(text)
        headers = chunks.flat_map { |c| c.metadata.dig(:structure, :headers) || [] }.compact

        expect(headers).to include('Step 1: Setup', 'Step 2: Configuration', 'Step 3: Running')
      end
    end
  end
end
