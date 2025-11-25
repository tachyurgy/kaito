# frozen_string_literal: true

require 'thor'
require 'json'
require 'fileutils'

module Kaito
  # Command-line interface for Kaito
  class CLI < Thor
    # Width of separator lines in output
    SEPARATOR_WIDTH = 60
    # Padding width for chunk file names
    FILE_NAME_PADDING = 4

    class_option :verbose, type: :boolean, aliases: '-v', desc: 'Verbose output'

    desc 'split FILE', 'Split a text file into chunks'
    method_option :strategy, type: :string, aliases: '-s', default: 'semantic',
                             desc: 'Splitting strategy (character, semantic, structure_aware, adaptive, recursive)'
    method_option :max_tokens, type: :numeric, aliases: '-m', default: 512,
                               desc: 'Maximum tokens per chunk'
    method_option :overlap, type: :numeric, aliases: '-o', default: 0,
                            desc: 'Number of tokens to overlap between chunks'
    method_option :tokenizer, type: :string, aliases: '-t', default: 'gpt4',
                              desc: 'Tokenizer to use (gpt35_turbo, gpt4, gpt4_turbo, character)'
    method_option :output, type: :string, aliases: '-out',
                           desc: 'Output directory for chunks (default: print to stdout)'
    method_option :format, type: :string, aliases: '-f', default: 'text',
                           desc: 'Output format (text, json, jsonl)'
    # Split a text file into chunks
    #
    # @param file [String] path to the file to split
    # @return [void]
    def split(file)
      # Sanitize file path to prevent path traversal
      safe_file = sanitize_path(file, type: :file)

      text = File.read(safe_file)

      # Split the text
      log "Splitting #{file} with strategy: #{options[:strategy]}"
      chunks = Kaito.split(
        text,
        strategy: options[:strategy].to_sym,
        max_tokens: options[:max_tokens],
        overlap_tokens: options[:overlap],
        tokenizer: options[:tokenizer].to_sym
      )

      log "Created #{chunks.length} chunks"

      # Output chunks
      if options[:output]
        output_to_directory(chunks, options[:output], options[:format])
      else
        output_to_stdout(chunks, options[:format])
      end
    rescue StandardError => e
      error "Failed to split file: #{e.message}"
      puts e.backtrace if options[:verbose]
      exit 1
    end

    desc 'count FILE', 'Count tokens in a file'
    method_option :tokenizer, type: :string, aliases: '-t', default: 'gpt4',
                              desc: 'Tokenizer to use (gpt35_turbo, gpt4, gpt4_turbo, character)'
    # Count tokens in a file
    #
    # @param file [String] path to the file
    # @return [void]
    def count(file)
      # Sanitize file path to prevent path traversal
      safe_file = sanitize_path(file, type: :file)

      text = File.read(safe_file)
      token_count = Kaito.count_tokens(text, tokenizer: options[:tokenizer].to_sym)

      puts "File: #{file}"
      puts "Tokenizer: #{options[:tokenizer]}"
      puts "Token count: #{token_count}"
      puts "Character count: #{text.length}"
    rescue StandardError => e
      error "Failed to count tokens: #{e.message}"
      puts e.backtrace if options[:verbose]
      exit 1
    end

    desc 'benchmark FILE', 'Benchmark different splitting strategies'
    method_option :strategies, type: :array, default: %w[character semantic structure_aware adaptive recursive],
                               desc: 'Strategies to benchmark'
    method_option :max_tokens, type: :numeric, aliases: '-m', default: 512,
                               desc: 'Maximum tokens per chunk'
    method_option :tokenizer, type: :string, aliases: '-t', default: 'gpt4',
                              desc: 'Tokenizer to use'
    # Benchmark different splitting strategies on a file
    #
    # @param file [String] path to the file to benchmark
    # @return [void]
    def benchmark(file)
      # Sanitize file path to prevent path traversal
      safe_file = sanitize_path(file, type: :file)

      require 'benchmark'

      text = File.read(safe_file)
      results = {}

      puts "Benchmarking strategies on #{file}"
      puts "File size: #{text.length} characters"
      puts "Max tokens: #{options[:max_tokens]}"
      puts '-' * SEPARATOR_WIDTH

      options[:strategies].each do |strategy|
        print "Testing #{strategy}... "

        begin
          time = Benchmark.realtime do
            chunks = Kaito.split(
              text,
              strategy: strategy.to_sym,
              max_tokens: options[:max_tokens],
              tokenizer: options[:tokenizer].to_sym
            )
            results[strategy] = {
              chunks: chunks.length,
              avg_tokens: chunks.sum(&:token_count) / chunks.length.to_f,
              time: 0 # Will be set below
            }
          end

          results[strategy][:time] = time
          puts "✓ (#{time.round(3)}s, #{results[strategy][:chunks]} chunks)"
        rescue StandardError => e
          puts "✗ (#{e.message})"
          results[strategy] = { error: e.message }
        end
      end

      puts "\n#{'=' * SEPARATOR_WIDTH}"
      puts 'RESULTS'
      puts '=' * SEPARATOR_WIDTH

      results.each do |strategy, data|
        if data[:error]
          puts "#{strategy}: ERROR - #{data[:error]}"
        else
          puts "#{strategy}:"
          puts "  Time: #{data[:time].round(3)}s"
          puts "  Chunks: #{data[:chunks]}"
          puts "  Avg tokens/chunk: #{data[:avg_tokens].round(1)}"
        end
      end
    rescue StandardError => e
      error "Benchmark failed: #{e.message}"
      puts e.backtrace if options[:verbose]
      exit 1
    end

    desc 'validate DIR', 'Validate chunks in a directory'
    method_option :check_overlap, type: :boolean, default: true,
                                  desc: 'Check for proper overlap between chunks'
    method_option :check_quality, type: :boolean, default: true,
                                  desc: 'Check chunk quality (coherence, completeness)'
    # Validate chunks in a directory for quality and overlap
    #
    # @param dir [String] directory containing chunk files
    # @return [void]
    def validate(dir)
      # Expand and validate directory path to prevent path traversal
      safe_dir = File.expand_path(dir)

      if dir.include?('..')
        error 'Directory path contains dangerous traversal sequences'
        exit 1
      end

      unless Dir.exist?(safe_dir)
        error "Directory not found: #{dir}"
        exit 1
      end

      files = Dir.glob(File.join(safe_dir, 'chunk_*.txt'))
      if files.empty?
        error "No chunk files found in #{dir}"
        exit 1
      end

      puts "Validating #{files.length} chunks in #{dir}"
      issues = []

      files.each_with_index do |file, idx|
        text = File.read(file)

        # Check if chunk is empty
        issues << "#{File.basename(file)}: Empty chunk" if text.strip.empty?

        # Check overlap with next chunk
        if options[:check_overlap] && idx < files.length - 1
          next_text = File.read(files[idx + 1])
          overlap = Kaito::Utils::TextUtils.find_overlap(text, next_text)
          issues << "#{File.basename(file)}: No overlap with next chunk" if overlap.nil?
        end

        # Basic quality checks
        next unless options[:check_quality]

        # Check if chunk ends mid-sentence
        issues << "#{File.basename(file)}: May end mid-sentence" unless /[.!?]\s*$/.match?(text)
      end

      if issues.empty?
        puts '✓ All chunks validated successfully'
      else
        puts "Found #{issues.length} issues:"
        issues.each { |issue| puts "  - #{issue}" }
        exit 1
      end
    rescue StandardError => e
      error "Validation failed: #{e.message}"
      puts e.backtrace if options[:verbose]
      exit 1
    end

    desc 'version', 'Show Kaito version'
    # Display the Kaito version
    #
    # @return [void]
    def version
      puts "Kaito version #{Kaito::VERSION}"
    end

    private

    # Sanitize file path to prevent path traversal attacks
    def sanitize_path(path, type: :file)
      # Expand path to absolute path and resolve any .. or . components
      expanded = File.expand_path(path)

      # Check for dangerous path patterns
      if path.include?('..') || path.include?('~')
        error 'Path contains potentially dangerous traversal sequences'
        exit 1
      end

      # For file paths, verify the file exists and is a file (not a directory or symlink to something dangerous)
      if (type == :file) && !(File.file?(expanded) && File.readable?(expanded))
        error "Invalid or unreadable file path: #{path}"
        exit 1
      end

      expanded
    end

    # Sanitize output directory path
    def sanitize_output_dir(dir)
      # Expand path to absolute path
      expanded = File.expand_path(dir)

      # Check for dangerous path patterns
      if dir.include?('..')
        error 'Output directory path contains dangerous traversal sequences'
        exit 1
      end

      # Prevent writing to system directories
      system_dirs = ['/bin', '/sbin', '/etc', '/usr', '/var', '/System', '/Library']
      if system_dirs.any? { |sys_dir| expanded.start_with?(sys_dir) }
        error "Cannot write to system directory: #{expanded}"
        exit 1
      end

      expanded
    end

    def output_to_stdout(chunks, format)
      case format
      when 'json'
        puts JSON.pretty_generate(chunks.map(&:to_h))
      when 'jsonl'
        chunks.each { |chunk| puts chunk.to_h.to_json }
      else # text
        chunks.each_with_index do |chunk, idx|
          puts '=' * SEPARATOR_WIDTH
          puts "Chunk #{idx + 1} (#{chunk.token_count} tokens)"
          puts '=' * SEPARATOR_WIDTH
          puts chunk.text
          puts
        end
      end
    end

    def output_to_directory(chunks, dir, format)
      # Sanitize output directory path to prevent path traversal
      safe_dir = sanitize_output_dir(dir)

      FileUtils.mkdir_p(safe_dir)
      log "Writing chunks to #{dir}"

      chunks.each_with_index do |chunk, idx|
        case format
        when 'json'
          file_path = File.join(safe_dir, "chunk_#{idx.to_s.rjust(FILE_NAME_PADDING, '0')}.json")
          File.write(file_path, JSON.pretty_generate(chunk.to_h))
        when 'jsonl'
          file_path = File.join(safe_dir, 'chunks.jsonl')
          File.open(file_path, 'a') { |f| f.puts chunk.to_h.to_json }
        else # text
          file_path = File.join(safe_dir, "chunk_#{idx.to_s.rjust(FILE_NAME_PADDING, '0')}.txt")
          File.write(file_path, chunk.text)
        end
      end

      log "Wrote #{chunks.length} chunks to #{dir}"
    end

    def log(message)
      puts message if options[:verbose]
    end

    def error(message)
      warn "ERROR: #{message}"
    end
  end
end
