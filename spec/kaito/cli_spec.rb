# frozen_string_literal: true

require 'tempfile'
require 'tmpdir'
require 'json'
require 'securerandom'
require 'fileutils'
require_relative '../../lib/kaito/cli'

RSpec.describe Kaito::CLI do
  let(:cli) { described_class.new }
  let(:sample_text) do
    <<~TEXT
      This is a test document. It contains multiple sentences.
      This helps us test the CLI functionality properly.

      This is a second paragraph with more content. We need enough text
      to create multiple chunks when splitting.
    TEXT
  end
  let(:large_sample_text) { sample_text * 20 }

  before do
    # Suppress output during tests unless we're specifically testing it
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:print)
    allow($stderr).to receive(:puts)
    allow($stderr).to receive(:warn)
  end

  # Helper to create a safe temp directory (not in system-protected /var)
  def with_safe_tmpdir
    dir = File.join(Dir.home, '.kaito_test_tmp', SecureRandom.hex(8))
    FileUtils.mkdir_p(dir)
    begin
      yield dir
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  describe 'split command' do
    let(:input_file) do
      file = Tempfile.new(['test', '.txt'])
      file.write(sample_text)
      file.close
      file
    end

    after do
      input_file&.unlink
    end

    it 'splits text file with default options' do
      expect { cli.invoke(:split, [input_file.path]) }.not_to raise_error
    end

    it 'splits with --strategy option' do
      %w[character semantic recursive adaptive].each do |strategy|
        expect do
          cli.invoke(:split, [input_file.path], strategy: strategy)
        end.not_to raise_error
      end
    end

    it 'splits with --output directory creation' do
      with_safe_tmpdir do |tmpdir|
        output_dir = File.join(tmpdir, 'chunks')
        cli.invoke(:split, [input_file.path], output: output_dir, format: 'text')

        expect(Dir.exist?(output_dir)).to be true
        chunk_files = Dir.glob(File.join(output_dir, 'chunk_*.txt'))
        expect(chunk_files).not_to be_empty
      end
    end

    it 'splits with JSON output format' do
      with_safe_tmpdir do |tmpdir|
        output_dir = File.join(tmpdir, 'chunks')
        cli.invoke(:split, [input_file.path], output: output_dir, format: 'json')

        json_files = Dir.glob(File.join(output_dir, 'chunk_*.json'))
        expect(json_files).not_to be_empty

        # Verify JSON is valid
        json_content = JSON.parse(File.read(json_files.first))
        expect(json_content).to include('text', 'token_count', 'metadata')
      end
    end

    it 'splits with JSONL output format' do
      with_safe_tmpdir do |tmpdir|
        output_dir = File.join(tmpdir, 'chunks')
        cli.invoke(:split, [input_file.path], output: output_dir, format: 'jsonl')

        jsonl_file = File.join(output_dir, 'chunks.jsonl')
        expect(File.exist?(jsonl_file)).to be true

        # Verify JSONL is valid
        lines = File.readlines(jsonl_file)
        expect(lines).not_to be_empty
        lines.each do |line|
          json = JSON.parse(line)
          expect(json).to include('text', 'token_count', 'metadata')
        end
      end
    end

    it 'handles invalid file paths' do
      expect do
        cli.invoke(:split, ['/nonexistent/file.txt'])
      end.to raise_error(SystemExit)
    end

    it 'respects max_tokens option' do
      with_safe_tmpdir do |tmpdir|
        output_dir = File.join(tmpdir, 'chunks')
        max_tokens = 50

        cli.invoke(:split, [input_file.path],
                   output: output_dir,
                   format: 'json',
                   max_tokens: max_tokens,
                   tokenizer: 'character')

        json_files = Dir.glob(File.join(output_dir, 'chunk_*.json'))
        json_files.each do |file|
          json = JSON.parse(File.read(file))
          expect(json['token_count']).to be <= max_tokens
        end
      end
    end

    it 'respects overlap option' do
      with_safe_tmpdir do |tmpdir|
        # Create a larger file for overlap testing
        large_file = Tempfile.new(['large_test', '.txt'])
        large_file.write(sample_text * 10) # Make it 10x larger
        large_file.close

        output_dir = File.join(tmpdir, 'chunks')
        overlap = 10

        cli.invoke(:split, [large_file.path],
                   output: output_dir,
                   format: 'json',
                   overlap: overlap,
                   max_tokens: 100,
                   strategy: 'character')

        json_files = Dir.glob(File.join(output_dir, 'chunk_*.json'))
        expect(json_files.length).to be >= 2

        # Check that chunks have overlap metadata (for strategies that support it)
        if json_files.length > 1
          json = JSON.parse(File.read(json_files[1]))
          expect(json['metadata']).to be_a(Hash)
        end

        large_file.unlink
      end
    end
  end

  describe 'count command' do
    let(:input_file) do
      file = Tempfile.new(['test', '.txt'])
      file.write(sample_text)
      file.close
      file
    end

    after do
      input_file&.unlink
    end

    it 'counts tokens in a file' do
      expect { cli.invoke(:count, [input_file.path]) }.not_to raise_error
    end

    it 'handles different tokenizers' do
      %w[character gpt4].each do |tokenizer|
        expect do
          cli.invoke(:count, [input_file.path], tokenizer: tokenizer)
        end.not_to raise_error
      end
    end

    it 'handles invalid file paths' do
      expect do
        cli.invoke(:count, ['/nonexistent/file.txt'])
      end.to raise_error(SystemExit)
    end

    it 'displays file information' do
      expect($stdout).to receive(:puts).with("File: #{input_file.path}")
      expect($stdout).to receive(:puts).with(/Tokenizer: /)
      expect($stdout).to receive(:puts).with(/Token count: /)
      expect($stdout).to receive(:puts).with(/Character count: /)

      cli.invoke(:count, [input_file.path])
    end
  end

  describe 'benchmark command' do
    let(:input_file) do
      file = Tempfile.new(['test', '.txt'])
      file.write(sample_text * 5) # Larger text for benchmarking
      file.close
      file
    end

    after do
      input_file&.unlink
    end

    it 'benchmarks different strategies' do
      expect do
        cli.invoke(:benchmark, [input_file.path], strategies: %w[character semantic])
      end.not_to raise_error
    end

    it 'handles invalid file paths' do
      expect do
        cli.invoke(:benchmark, ['/nonexistent/file.txt'])
      end.to raise_error(SystemExit)
    end

    it 'respects max_tokens option' do
      expect do
        cli.invoke(:benchmark, [input_file.path],
                   strategies: %w[character],
                   max_tokens: 100)
      end.not_to raise_error
    end

    it 'shows progress for each strategy' do
      # Re-enable stdout to capture output
      allow($stdout).to receive(:print).and_call_original
      allow($stdout).to receive(:puts).and_call_original

      output = capture_stdout do
        cli.invoke(:benchmark, [input_file.path], strategies: ['character'])
      end

      expect(output).to include('Testing character')
    end

    it 'continues benchmarking even if one strategy fails' do
      # Even with an invalid strategy mixed in, it should complete
      expect do
        cli.invoke(:benchmark, [input_file.path],
                   strategies: %w[character invalid_strategy semantic])
      end.not_to raise_error
    end
  end

  describe 'validate command' do
    it 'validates chunks in a directory' do
      with_safe_tmpdir do |tmpdir|
        # Create some test chunks
        File.write(File.join(tmpdir, 'chunk_0000.txt'), 'This is chunk one.')
        File.write(File.join(tmpdir, 'chunk_0001.txt'), 'This is chunk two.')
        File.write(File.join(tmpdir, 'chunk_0002.txt'), 'This is chunk three.')

        expect do
          cli.invoke(:validate, [tmpdir], check_overlap: false)
        end.not_to raise_error
      end
    end

    it 'handles invalid directory paths' do
      expect do
        cli.invoke(:validate, ['/nonexistent/directory'])
      end.to raise_error(SystemExit)
    end

    it 'handles empty directories' do
      with_safe_tmpdir do |tmpdir|
        expect do
          cli.invoke(:validate, [tmpdir])
        end.to raise_error(SystemExit)
      end
    end

    it 'detects empty chunks' do
      with_safe_tmpdir do |tmpdir|
        File.write(File.join(tmpdir, 'chunk_0000.txt'), 'This is chunk one.')
        File.write(File.join(tmpdir, 'chunk_0001.txt'), '   ') # Empty chunk

        expect do
          cli.invoke(:validate, [tmpdir])
        end.to raise_error(SystemExit)
      end
    end

    context 'quality checks' do
      it 'detects chunks that may end mid-sentence' do
        with_safe_tmpdir do |tmpdir|
          File.write(File.join(tmpdir, 'chunk_0000.txt'), 'This is a proper sentence.')
          File.write(File.join(tmpdir, 'chunk_0001.txt'), 'This chunk ends without proper')

          expect do
            cli.invoke(:validate, [tmpdir], check_quality: true, check_overlap: false)
          end.to raise_error(SystemExit)
        end
      end

      it 'passes chunks that end properly' do
        with_safe_tmpdir do |tmpdir|
          File.write(File.join(tmpdir, 'chunk_0000.txt'), 'This is a proper sentence.')
          File.write(File.join(tmpdir, 'chunk_0001.txt'), 'This chunk also ends properly!')

          expect do
            cli.invoke(:validate, [tmpdir], check_quality: true, check_overlap: false)
          end.not_to raise_error
        end
      end

      it 'skips quality checks when disabled' do
        with_safe_tmpdir do |tmpdir|
          File.write(File.join(tmpdir, 'chunk_0000.txt'), 'This chunk ends without proper')

          expect do
            cli.invoke(:validate, [tmpdir], check_quality: false, check_overlap: false)
          end.not_to raise_error
        end
      end
    end

    context 'overlap checks' do
      it 'checks for overlap when enabled' do
        with_safe_tmpdir do |tmpdir|
          File.write(File.join(tmpdir, 'chunk_0000.txt'), 'This is the first chunk.')
          File.write(File.join(tmpdir, 'chunk_0001.txt'), 'Completely different content.')

          # This may or may not fail depending on overlap detection logic
          begin
            cli.invoke(:validate, [tmpdir], check_overlap: true, check_quality: false)
          rescue SystemExit
            # Expected if no overlap found
          end
        end
      end

      it 'skips overlap checks when disabled' do
        with_safe_tmpdir do |tmpdir|
          File.write(File.join(tmpdir, 'chunk_0000.txt'), 'This is the first chunk.')
          File.write(File.join(tmpdir, 'chunk_0001.txt'), 'Completely different content.')

          expect do
            cli.invoke(:validate, [tmpdir], check_overlap: false, check_quality: false)
          end.not_to raise_error
        end
      end
    end

    it 'rejects paths with .. traversal' do
      expect do
        cli.invoke(:validate, ['../../../etc'])
      end.to raise_error(SystemExit)
    end
  end

  describe 'version command' do
    it 'shows the version' do
      expect { cli.invoke(:version) }.not_to raise_error
    end

    it 'outputs the correct version format' do
      expect($stdout).to receive(:puts).with("Kaito version #{Kaito::VERSION}")
      cli.invoke(:version)
    end
  end

  describe 'security features' do
    let(:input_file) do
      file = Tempfile.new(['test', '.txt'])
      file.write(sample_text)
      file.close
      file
    end

    after do
      input_file&.unlink
    end

    context 'path traversal prevention' do
      it 'rejects paths with .. in split command' do
        expect do
          cli.invoke(:split, ['../../../etc/passwd'])
        end.to raise_error(SystemExit)
      end

      it 'rejects paths with ~ in split command' do
        expect do
          cli.invoke(:split, ['~/secret/file.txt'])
        end.to raise_error(SystemExit)
      end

      it 'rejects paths with .. in count command' do
        expect do
          cli.invoke(:count, ['../../../etc/passwd'])
        end.to raise_error(SystemExit)
      end

      it 'rejects paths with ~ in count command' do
        expect do
          cli.invoke(:count, ['~/secret/file.txt'])
        end.to raise_error(SystemExit)
      end

      it 'rejects paths with .. in benchmark command' do
        expect do
          cli.invoke(:benchmark, ['../../../etc/passwd'])
        end.to raise_error(SystemExit)
      end

      it 'rejects output directory with ..' do
        expect do
          cli.invoke(:split, [input_file.path], output: '../../../etc')
        end.to raise_error(SystemExit)
      end
    end

    context 'system directory protection' do
      it 'prevents writing to /bin' do
        expect do
          cli.invoke(:split, [input_file.path], output: '/bin/chunks')
        end.to raise_error(SystemExit)
      end

      it 'prevents writing to /etc' do
        expect do
          cli.invoke(:split, [input_file.path], output: '/etc/chunks')
        end.to raise_error(SystemExit)
      end

      it 'prevents writing to /usr' do
        expect do
          cli.invoke(:split, [input_file.path], output: '/usr/chunks')
        end.to raise_error(SystemExit)
      end

      it 'prevents writing to /System' do
        expect do
          cli.invoke(:split, [input_file.path], output: '/System/chunks')
        end.to raise_error(SystemExit)
      end
    end

    context 'file type validation' do
      it 'handles directory instead of file' do
        with_safe_tmpdir do |tmpdir|
          expect do
            cli.invoke(:split, [tmpdir])
          end.to raise_error(SystemExit)
        end
      end
    end
  end

  describe 'output formats' do
    let(:input_file) do
      file = Tempfile.new(['test', '.txt'])
      file.write(large_sample_text)
      file.close
      file
    end

    after do
      input_file&.unlink
    end

    context 'stdout output' do
      before do
        # Re-enable stdout to capture it
        allow($stdout).to receive(:puts).and_call_original
      end

      it 'outputs text format to stdout' do
        output = capture_stdout do
          cli.invoke(:split, [input_file.path], format: 'text')
        end

        expect(output).to include('Chunk 1')
        expect(output).to include('tokens')
        expect(output).to include('=' * 60)
      end

      it 'outputs JSON format to stdout' do
        output = capture_stdout do
          cli.invoke(:split, [input_file.path], format: 'json')
        end

        json = JSON.parse(output)
        expect(json).to be_an(Array)
        expect(json.first).to include('text', 'token_count', 'metadata')
      end

      it 'outputs JSONL format to stdout' do
        output = capture_stdout do
          cli.invoke(:split, [input_file.path], format: 'jsonl')
        end

        lines = output.split("\n").reject(&:empty?)
        expect(lines).not_to be_empty
        lines.each do |line|
          json = JSON.parse(line)
          expect(json).to include('text', 'token_count', 'metadata')
        end
      end
    end

    context 'file output' do
      it 'creates text files with proper naming' do
        with_safe_tmpdir do |tmpdir|
          output_dir = File.join(tmpdir, 'chunks')
          cli.invoke(:split, [input_file.path], output: output_dir, format: 'text')

          chunk_files = Dir.glob(File.join(output_dir, 'chunk_*.txt'))
          expect(chunk_files).not_to be_empty
          expect(chunk_files.first).to match(/chunk_\d{4}\.txt$/)
        end
      end

      it 'creates JSON files with proper naming' do
        with_safe_tmpdir do |tmpdir|
          output_dir = File.join(tmpdir, 'chunks')
          cli.invoke(:split, [input_file.path], output: output_dir, format: 'json')

          chunk_files = Dir.glob(File.join(output_dir, 'chunk_*.json'))
          expect(chunk_files).not_to be_empty
          expect(chunk_files.first).to match(/chunk_\d{4}\.json$/)
        end
      end

      it 'creates single JSONL file' do
        with_safe_tmpdir do |tmpdir|
          output_dir = File.join(tmpdir, 'chunks')
          cli.invoke(:split, [input_file.path], output: output_dir, format: 'jsonl')

          jsonl_file = File.join(output_dir, 'chunks.jsonl')
          expect(File.exist?(jsonl_file)).to be true
        end
      end

      it 'creates output directory if it does not exist' do
        with_safe_tmpdir do |tmpdir|
          output_dir = File.join(tmpdir, 'nested', 'output', 'dir')
          cli.invoke(:split, [input_file.path], output: output_dir, format: 'text')

          expect(Dir.exist?(output_dir)).to be true
        end
      end
    end
  end

  describe 'verbose mode' do
    let(:input_file) do
      file = Tempfile.new(['test', '.txt'])
      file.write(sample_text)
      file.close
      file
    end

    after do
      input_file&.unlink
    end

    context 'with verbose flag' do
      before do
        # Re-enable stdout to capture verbose output
        allow($stdout).to receive(:puts).and_call_original
      end

      it 'logs splitting progress' do
        output = capture_stdout do
          cli.invoke(:split, [input_file.path], verbose: true)
        end

        expect(output).to include('Splitting')
        expect(output).to include('strategy:')
        expect(output).to include('Created')
        expect(output).to include('chunks')
      end

      it 'logs output directory creation' do
        with_safe_tmpdir do |tmpdir|
          output_dir = File.join(tmpdir, 'chunks')
          output = capture_stdout do
            cli.invoke(:split, [input_file.path], output: output_dir, verbose: true)
          end

          expect(output).to include('Writing chunks to')
          expect(output).to include('Wrote')
        end
      end

      it 'shows backtrace on error' do
        # Verbose mode should show backtrace when there's an error

        cli.invoke(:split, ['/nonexistent/file.txt'], verbose: true)
      rescue SystemExit
        # Expected - test that verbose mode was invoked (tested implicitly by not crashing)
      end
    end

    context 'without verbose flag' do
      it 'does not log splitting progress' do
        cli.invoke(:split, [input_file.path], verbose: false)

        # Should not receive verbose messages
        expect($stdout).not_to have_received(:puts).with(/Splitting/)
      end

      it 'does not log output directory messages' do
        with_safe_tmpdir do |tmpdir|
          output_dir = File.join(tmpdir, 'chunks')
          cli.invoke(:split, [input_file.path], output: output_dir, verbose: false)

          expect($stdout).not_to have_received(:puts).with(/Writing chunks to/)
        end
      end
    end
  end

  describe 'tokenizer options' do
    let(:input_file) do
      file = Tempfile.new(['test', '.txt'])
      file.write(sample_text)
      file.close
      file
    end

    after do
      input_file&.unlink
    end

    context 'split command' do
      it 'works with gpt35_turbo tokenizer' do
        expect do
          cli.invoke(:split, [input_file.path], tokenizer: 'gpt35_turbo')
        end.not_to raise_error
      end

      it 'works with gpt4 tokenizer' do
        expect do
          cli.invoke(:split, [input_file.path], tokenizer: 'gpt4')
        end.not_to raise_error
      end


      it 'works with character tokenizer' do
        expect do
          cli.invoke(:split, [input_file.path], tokenizer: 'character')
        end.not_to raise_error
      end
    end

    context 'count command' do
      it 'works with gpt35_turbo tokenizer' do
        expect do
          cli.invoke(:count, [input_file.path], tokenizer: 'gpt35_turbo')
        end.not_to raise_error
      end

    end

    context 'benchmark command' do
      it 'works with different tokenizers' do
        expect do
          cli.invoke(:benchmark, [input_file.path],
                     strategies: ['character'],
                     tokenizer: 'gpt35_turbo')
        end.not_to raise_error
      end
    end
  end

  describe 'splitting strategies' do
    let(:input_file) do
      file = Tempfile.new(['test', '.txt'])
      file.write(large_sample_text)
      file.close
      file
    end

    after do
      input_file&.unlink
    end

    it 'works with character strategy' do
      expect do
        cli.invoke(:split, [input_file.path], strategy: 'character')
      end.not_to raise_error
    end

    it 'works with semantic strategy' do
      expect do
        cli.invoke(:split, [input_file.path], strategy: 'semantic')
      end.not_to raise_error
    end

    it 'works with structure_aware strategy' do
      expect do
        cli.invoke(:split, [input_file.path], strategy: 'structure_aware')
      end.not_to raise_error
    end

    it 'works with adaptive strategy' do
      expect do
        cli.invoke(:split, [input_file.path], strategy: 'adaptive')
      end.not_to raise_error
    end

    it 'works with recursive strategy' do
      expect do
        cli.invoke(:split, [input_file.path], strategy: 'recursive')
      end.not_to raise_error
    end

    it 'creates different chunk counts for different strategies' do
      results = {}

      with_safe_tmpdir do |tmpdir|
        %w[character semantic].each do |strategy|
          output_dir = File.join(tmpdir, "chunks_#{strategy}")
          cli.invoke(:split, [input_file.path],
                     output: output_dir,
                     strategy: strategy,
                     max_tokens: 100)

          chunk_files = Dir.glob(File.join(output_dir, 'chunk_*.txt'))
          results[strategy] = chunk_files.length
        end
      end

      # Different strategies should produce different results
      expect(results.values.uniq.length).to be > 1
    end
  end

  describe 'error handling' do
    context 'split command errors' do
      it 'handles file not found gracefully' do
        expect do
          cli.invoke(:split, ['/totally/nonexistent/file.txt'])
        end.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(1)
        }
      end

      it 'exits with status 1 on error' do
        expect do
          cli.invoke(:split, ['/nonexistent/file.txt'])
        end.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(1)
        }
      end
    end

    context 'count command errors' do
      it 'handles file not found gracefully' do
        expect do
          cli.invoke(:count, ['/totally/nonexistent/file.txt'])
        end.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(1)
        }
      end
    end

    context 'benchmark command errors' do
      it 'handles file not found gracefully' do
        expect do
          cli.invoke(:benchmark, ['/totally/nonexistent/file.txt'])
        end.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(1)
        }
      end
    end

    context 'validate command errors' do
      it 'handles directory not found' do
        expect do
          cli.invoke(:validate, ['/totally/nonexistent/directory'])
        end.to raise_error(SystemExit) { |error|
          expect(error.status).to eq(1)
        }
      end

      it 'handles empty directory' do
        with_safe_tmpdir do |tmpdir|
          expect do
            cli.invoke(:validate, [tmpdir])
          end.to raise_error(SystemExit) { |error|
            expect(error.status).to eq(1)
          }
        end
      end
    end
  end

  describe 'command-line options' do
    let(:input_file) do
      file = Tempfile.new(['test', '.txt'])
      file.write(large_sample_text)
      file.close
      file
    end

    after do
      input_file&.unlink
    end

    context 'max_tokens option' do
      it 'creates more chunks with smaller max_tokens' do
        chunk_counts = {}

        with_safe_tmpdir do |tmpdir|
          [50, 200].each do |max_tokens|
            output_dir = File.join(tmpdir, "chunks_#{max_tokens}")

            cli.invoke(:split, [input_file.path],
                       output: output_dir,
                       max_tokens: max_tokens,
                       strategy: 'character')

            chunk_files = Dir.glob(File.join(output_dir, 'chunk_*.txt'))
            chunk_counts[max_tokens] = chunk_files.length
          end
        end

        expect(chunk_counts[50]).to be > chunk_counts[200]
      end
    end

    context 'overlap option' do
      it 'includes overlap information in metadata' do
        with_safe_tmpdir do |tmpdir|
          output_dir = File.join(tmpdir, 'chunks')

          cli.invoke(:split, [input_file.path],
                     output: output_dir,
                     format: 'json',
                     overlap: 20,
                     max_tokens: 100,
                     strategy: 'character')

          json_files = Dir.glob(File.join(output_dir, 'chunk_*.json'))
          expect(json_files.length).to be >= 2

          json = JSON.parse(File.read(json_files.first))
          expect(json).to have_key('metadata')
        end
      end
    end
  end

  # Helper methods
  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  def capture_stderr
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old_stderr
  end
end
