# frozen_string_literal: true

require "thor"
require "json"
require "fileutils"

module Kaito
  # Command-line interface for Kaito
  class CLI < Thor
    class_option :verbose, type: :boolean, aliases: "-v", desc: "Verbose output"

    desc "split FILE", "Split a text file into chunks"
    method_option :strategy, type: :string, aliases: "-s", default: "semantic",
                  desc: "Splitting strategy (character, semantic, structure_aware, adaptive, recursive)"
    method_option :max_tokens, type: :numeric, aliases: "-m", default: 512,
                  desc: "Maximum tokens per chunk"
    method_option :overlap, type: :numeric, aliases: "-o", default: 0,
                  desc: "Number of tokens to overlap between chunks"
    method_option :tokenizer, type: :string, aliases: "-t", default: "gpt4",
                  desc: "Tokenizer to use (gpt35_turbo, gpt4, claude, character)"
    method_option :output, type: :string, aliases: "-out",
                  desc: "Output directory for chunks (default: print to stdout)"
    method_option :format, type: :string, aliases: "-f", default: "text",
                  desc: "Output format (text, json, jsonl)"
    def split(file)
      unless File.exist?(file)
        error "File not found: #{file}"
        exit 1
      end

      text = File.read(file)

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

    desc "count FILE", "Count tokens in a file"
    method_option :tokenizer, type: :string, aliases: "-t", default: "gpt4",
                  desc: "Tokenizer to use (gpt35_turbo, gpt4, claude, character)"
    def count(file)
      unless File.exist?(file)
        error "File not found: #{file}"
        exit 1
      end

      text = File.read(file)
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

    desc "benchmark FILE", "Benchmark different splitting strategies"
    method_option :strategies, type: :array, default: %w[character semantic structure_aware adaptive recursive],
                  desc: "Strategies to benchmark"
    method_option :max_tokens, type: :numeric, aliases: "-m", default: 512,
                  desc: "Maximum tokens per chunk"
    method_option :tokenizer, type: :string, aliases: "-t", default: "gpt4",
                  desc: "Tokenizer to use"
    def benchmark(file)
      unless File.exist?(file)
        error "File not found: #{file}"
        exit 1
      end

      require "benchmark"

      text = File.read(file)
      results = {}

      puts "Benchmarking strategies on #{file}"
      puts "File size: #{text.length} characters"
      puts "Max tokens: #{options[:max_tokens]}"
      puts "-" * 60

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

      puts "\n" + "=" * 60
      puts "RESULTS"
      puts "=" * 60

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

    desc "validate DIR", "Validate chunks in a directory"
    method_option :check_overlap, type: :boolean, default: true,
                  desc: "Check for proper overlap between chunks"
    method_option :check_quality, type: :boolean, default: true,
                  desc: "Check chunk quality (coherence, completeness)"
    def validate(dir)
      unless Dir.exist?(dir)
        error "Directory not found: #{dir}"
        exit 1
      end

      files = Dir.glob(File.join(dir, "chunk_*.txt")).sort
      if files.empty?
        error "No chunk files found in #{dir}"
        exit 1
      end

      puts "Validating #{files.length} chunks in #{dir}"
      issues = []

      files.each_with_index do |file, idx|
        text = File.read(file)

        # Check if chunk is empty
        if text.strip.empty?
          issues << "#{File.basename(file)}: Empty chunk"
        end

        # Check overlap with next chunk
        if options[:check_overlap] && idx < files.length - 1
          next_text = File.read(files[idx + 1])
          overlap = Kaito::Utils::TextUtils.find_overlap(text, next_text)
          issues << "#{File.basename(file)}: No overlap with next chunk" if overlap.nil?
        end

        # Basic quality checks
        if options[:check_quality]
          # Check if chunk ends mid-sentence
          unless text =~ /[.!?]\s*$/
            issues << "#{File.basename(file)}: May end mid-sentence"
          end
        end
      end

      if issues.empty?
        puts "✓ All chunks validated successfully"
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

    desc "version", "Show Kaito version"
    def version
      puts "Kaito version #{Kaito::VERSION}"
    end

    private

    def output_to_stdout(chunks, format)
      case format
      when "json"
        puts JSON.pretty_generate(chunks.map(&:to_h))
      when "jsonl"
        chunks.each { |chunk| puts chunk.to_h.to_json }
      else # text
        chunks.each_with_index do |chunk, idx|
          puts "=" * 60
          puts "Chunk #{idx + 1} (#{chunk.token_count} tokens)"
          puts "=" * 60
          puts chunk.text
          puts
        end
      end
    end

    def output_to_directory(chunks, dir, format)
      FileUtils.mkdir_p(dir)
      log "Writing chunks to #{dir}"

      chunks.each_with_index do |chunk, idx|
        case format
        when "json"
          file_path = File.join(dir, "chunk_#{idx.to_s.rjust(4, '0')}.json")
          File.write(file_path, JSON.pretty_generate(chunk.to_h))
        when "jsonl"
          file_path = File.join(dir, "chunks.jsonl")
          File.open(file_path, "a") { |f| f.puts chunk.to_h.to_json }
        else # text
          file_path = File.join(dir, "chunk_#{idx.to_s.rjust(4, '0')}.txt")
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
