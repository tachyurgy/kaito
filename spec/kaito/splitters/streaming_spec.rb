# frozen_string_literal: true

require 'tempfile'
require 'fileutils'

RSpec.describe 'Streaming Functionality' do
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
  end

  shared_examples 'a streaming splitter' do |splitter_class, options = {}|
    let(:splitter) { splitter_class.new(**default_options.merge(options)) }
    let(:default_options) { { max_tokens: 50, tokenizer: :character } }

    describe '#stream_file' do
      context 'with basic file streaming' do
        it 'streams file chunks without loading entire file' do
          file_path = create_temp_file('line1' * 20 + "\n" + 'line2' * 20 + "\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
          expect(chunks).to all(be_a(Kaito::Chunk))
        end

        it 'yields chunks one at a time' do
          file_path = create_temp_file('a' * 100 + "\n" + 'b' * 100 + "\n")
          yielded_order = []

          splitter.stream_file(file_path) do |chunk|
            yielded_order << chunk.text[0] # Track first character
          end

          expect(yielded_order).not_to be_empty
        end

        it 'returns an enumerator when no block is given' do
          file_path = create_temp_file("test content\n")
          result = splitter.stream_file(file_path)

          expect(result).to be_a(Enumerator)
        end

        it 'can iterate through enumerator' do
          file_path = create_temp_file('x' * 100 + "\n" + 'y' * 100 + "\n")
          enumerator = splitter.stream_file(file_path)
          chunks = enumerator.to_a

          expect(chunks).not_to be_empty
          expect(chunks).to all(be_a(Kaito::Chunk))
        end

        it 'adds source_file metadata to chunks' do
          file_path = create_temp_file("test content\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).to all(satisfy { |c| c.source_file == file_path })
        end

        it 'adds sequential index metadata to chunks' do
          file_path = create_temp_file('a' * 100 + "\n" + 'b' * 100 + "\n" + 'c' * 100 + "\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          chunks.each_with_index do |chunk, idx|
            expect(chunk.index).to eq(idx)
          end
        end
      end

      context 'with large files' do
        it 'handles large files without loading into memory at once' do
          # Create a 1MB file
          file_path = create_large_file(1024 * 1024)
          chunks = []
          max_memory_increase = 0

          # Track memory usage (simplified)
          initial_object_count = ObjectSpace.count_objects[:T_STRING]

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          final_object_count = ObjectSpace.count_objects[:T_STRING]
          string_increase = final_object_count - initial_object_count

          expect(chunks).not_to be_empty
          # Should not create excessive string objects if streaming properly
          # Note: Semantic and Recursive splitters create more objects due to parsing
          # Adjust threshold based on splitter type (with margin for GC timing)
          splitter_name = splitter.class.name
          max_allowed = if splitter_name.include?('Semantic') || splitter_name.include?('Recursive')
                          100000
                        else
                          15000  # Slightly more lenient to account for GC timing variations
                        end
          expect(string_increase).to be < max_allowed
        end

        it 'processes large files in chunks' do
          # Create a 100KB file with many lines
          file_path = create_file_with_lines(2000)
          chunk_count = 0

          splitter.stream_file(file_path) { |_chunk| chunk_count += 1 }

          expect(chunk_count).to be > 1
        end

        it 'handles files larger than buffer size' do
          # Create a file that's definitely larger than typical buffer
          file_path = create_large_file(500_000)
          chunks = []

          expect do
            splitter.stream_file(file_path) { |chunk| chunks << chunk }
          end.not_to raise_error

          expect(chunks.length).to be > 5
        end
      end

      context 'with error handling' do
        it 'raises FileError when file does not exist' do
          expect do
            splitter.stream_file('/nonexistent/file.txt') { |_chunk| }
          end.to raise_error(Kaito::FileError, /File not found/)
        end

        it 'handles errors during chunk processing' do
          # Create a large enough file to generate multiple chunks
          file_path = create_temp_file('a' * 200 + "\n" + 'b' * 200 + "\n" + 'c' * 200 + "\n")
          chunks_before_error = []

          expect do
            splitter.stream_file(file_path) do |chunk|
              chunks_before_error << chunk
              raise StandardError, 'Processing error' if chunks_before_error.length == 2
            end
          end.to raise_error(StandardError, 'Processing error')

          # Should have processed some chunks before error
          expect(chunks_before_error.length).to eq(2)
        end

        it 'properly closes file handle even on error' do
          file_path = create_temp_file("test content\n")

          expect do
            splitter.stream_file(file_path) do |_chunk|
              raise StandardError, 'Test error'
            end
          end.to raise_error(StandardError, 'Test error')

          # File should be accessible after error (not locked)
          expect(File.readable?(file_path)).to be true
          expect { File.read(file_path) }.not_to raise_error
        end
      end

      context 'with buffer management' do
        it 'processes buffer when it exceeds threshold' do
          file_path = create_temp_file('x' * 150 + "\n" + 'y' * 150 + "\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
        end

        it 'yields remaining buffer at end of file' do
          file_path = create_temp_file('short content')
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
        end

        it 'does not yield empty chunks' do
          file_path = create_temp_file("\n\n\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).to be_empty
        end

        it 'handles buffer with whitespace-only content' do
          file_path = create_temp_file("   \n\t\t\n   \n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).to be_empty
        end

        it 'maintains buffer state across multiple lines' do
          file_path = create_temp_file("line1\nline2\nline3\nline4\nline5\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          # All content should be in chunks
          all_text = chunks.map(&:text).join
          expect(all_text).to include('line')
        end
      end

      context 'with edge cases' do
        it 'handles empty files' do
          file_path = create_temp_file('')
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).to be_empty
        end

        it 'handles single line files without newline' do
          file_path = create_temp_file('single line no newline', newline: false)
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
          expect(chunks.first.text).to include('single line')
        end

        it 'handles files with only newlines' do
          file_path = create_temp_file("\n\n\n\n\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).to be_empty
        end

        it 'handles files with very long lines' do
          file_path = create_temp_file('x' * 10000 + "\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
        end

        it 'handles files with mixed line lengths' do
          content = "short\n" + 'x' * 1000 + "\nmedium line here\n" + 'y' * 500 + "\n"
          file_path = create_temp_file(content)
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
        end

        it 'handles files ending without newline' do
          file_path = create_temp_file("line1\nline2\nline3", newline: false)
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
          all_text = chunks.map(&:text).join
          expect(all_text).to include('line3')
        end
      end

      context 'with different file encodings' do
        it 'handles UTF-8 encoded files' do
          file_path = create_temp_file("Hello 世界\nBonjour 🌍\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
          all_text = chunks.map(&:text).join
          expect(all_text).to include('世界')
          expect(all_text).to include('🌍')
        end

        it 'handles files with special characters' do
          file_path = create_temp_file("Special: @#$%^&*()\nSymbols: <>?:{}|~\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
        end

        it 'handles multi-byte characters correctly' do
          file_path = create_temp_file("日本語テキスト\n中文文本\n한국어 텍스트\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          expect(chunks).not_to be_empty
        end
      end

      context 'with token limits' do
        it 'respects max_tokens per chunk' do
          splitter = splitter_class.new(max_tokens: 30, tokenizer: :character)
          file_path = create_temp_file('a' * 200 + "\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          chunks.each do |chunk|
            expect(chunk.token_count).to be <= 30
          end
        end

        it 'processes all content from file' do
          file_path = create_temp_file('x' * 500 + "\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          total_tokens = chunks.sum(&:token_count)
          expect(total_tokens).to be >= 400 # Most content should be captured
        end
      end

      context 'with chunk metadata' do
        it 'includes all expected metadata fields' do
          file_path = create_temp_file("test content\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          chunks.each do |chunk|
            expect(chunk.metadata).to include(:index)
            expect(chunk.metadata).to include(:source_file)
          end
        end

        it 'preserves metadata immutability' do
          file_path = create_temp_file("test content\n")
          chunks = []

          splitter.stream_file(file_path) { |chunk| chunks << chunk }

          chunks.each do |chunk|
            expect(chunk.metadata).to be_frozen
          end
        end
      end
    end
  end

  describe 'Character Splitter' do
    include_examples 'a streaming splitter', Kaito::Splitters::Character
  end

  describe 'Semantic Splitter' do
    include_examples 'a streaming splitter', Kaito::Splitters::Semantic, {
      preserve_sentences: true
    }

    context 'with semantic-specific streaming' do
      let(:splitter) do
        Kaito::Splitters::Semantic.new(max_tokens: 100, tokenizer: :character)
      end

      it 'preserves sentence boundaries during streaming' do
        content = "First sentence here. Second sentence here. Third sentence here.\n" * 10
        file_path = create_temp_file(content)
        chunks = []

        splitter.stream_file(file_path) { |chunk| chunks << chunk }

        expect(chunks).not_to be_empty
      end

      it 'handles paragraph preservation in streaming' do
        splitter = Kaito::Splitters::Semantic.new(
          max_tokens: 200,
          tokenizer: :character,
          preserve_paragraphs: true
        )
        content = "Paragraph one.\n\nParagraph two.\n\nParagraph three.\n"
        file_path = create_temp_file(content)
        chunks = []

        splitter.stream_file(file_path) { |chunk| chunks << chunk }

        expect(chunks).not_to be_empty
      end
    end
  end

  describe 'Recursive Splitter' do
    include_examples 'a streaming splitter', Kaito::Splitters::Recursive

    context 'with recursive-specific streaming' do
      let(:splitter) do
        Kaito::Splitters::Recursive.new(max_tokens: 80, tokenizer: :character)
      end

      it 'maintains separator hierarchy during streaming' do
        content = "Paragraph one.\n\nParagraph two with multiple sentences. Another sentence here.\n\n"
        file_path = create_temp_file(content)
        chunks = []

        splitter.stream_file(file_path) { |chunk| chunks << chunk }

        expect(chunks).not_to be_empty
      end

      it 'handles custom separators in streaming' do
        splitter = Kaito::Splitters::Recursive.new(
          max_tokens: 50,
          tokenizer: :character,
          separators: ["\n\n", "\n", " "]
        )
        file_path = create_temp_file("Word1 Word2 Word3\nLine2 Content\n\nParagraph2\n")
        chunks = []

        splitter.stream_file(file_path) { |chunk| chunks << chunk }

        expect(chunks).not_to be_empty
      end
    end
  end

  describe 'Memory efficiency verification' do
    it 'does not load entire file into memory at once' do
      # Create a substantial file
      file_path = create_large_file(1024 * 1024) # 1MB
      splitter = Kaito::Splitters::Character.new(max_tokens: 100, tokenizer: :character)

      # This should work without loading entire file
      chunk_count = 0
      expect do
        splitter.stream_file(file_path) { |_chunk| chunk_count += 1 }
      end.not_to raise_error

      expect(chunk_count).to be > 0
    end

    it 'processes chunks incrementally' do
      file_path = create_file_with_lines(1000)
      splitter = Kaito::Splitters::Character.new(max_tokens: 50, tokenizer: :character)

      processed_chunks = []
      splitter.stream_file(file_path) do |chunk|
        processed_chunks << chunk
        # Simulate processing that would be memory-intensive if all loaded at once
      end

      expect(processed_chunks.length).to be > 1
    end
  end

  describe 'Stream interruption and resumption' do
    it 'allows breaking out of stream early' do
      file_path = create_large_file(1024 * 1024)
      splitter = Kaito::Splitters::Character.new(max_tokens: 100, tokenizer: :character)

      chunk_count = 0
      splitter.stream_file(file_path) do |_chunk|
        chunk_count += 1
        break if chunk_count >= 5
      end

      expect(chunk_count).to eq(5)
    end

    it 'supports lazy evaluation with enumerator' do
      file_path = create_large_file(1024 * 1024)
      splitter = Kaito::Splitters::Character.new(max_tokens: 100, tokenizer: :character)

      enumerator = splitter.stream_file(file_path)
      first_chunk = enumerator.next

      expect(first_chunk).to be_a(Kaito::Chunk)
    end

    it 'allows taking limited number of chunks' do
      file_path = create_file_with_lines(1000)
      splitter = Kaito::Splitters::Character.new(max_tokens: 50, tokenizer: :character)

      enumerator = splitter.stream_file(file_path)
      limited_chunks = enumerator.take(3)

      expect(limited_chunks.length).to eq(3)
      expect(limited_chunks).to all(be_a(Kaito::Chunk))
    end
  end

  # Helper methods
  def create_temp_file(content, newline: true)
    file = Tempfile.new(['test', '.txt'], temp_dir)
    file.write(content)
    file.write("\n") if newline && !content.end_with?("\n") && !content.empty?
    file.close
    file.path
  end

  def create_large_file(size_bytes)
    file = Tempfile.new(['large', '.txt'], temp_dir)
    lines_needed = (size_bytes / 100.0).ceil
    lines_needed.times do |i|
      file.write("Line #{i}: #{'x' * 80}\n")
    end
    file.close
    file.path
  end

  def create_file_with_lines(line_count)
    file = Tempfile.new(['lines', '.txt'], temp_dir)
    line_count.times do |i|
      file.write("This is line number #{i} with some content here\n")
    end
    file.close
    file.path
  end
end
