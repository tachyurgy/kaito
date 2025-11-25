# frozen_string_literal: true

module Kaito
  module Splitters
    # Structure-aware splitter that respects document structure
    # Handles markdown headers, code blocks, lists, and other structural elements
    class StructureAware < Base
      attr_reader :preserve_code_blocks, :preserve_lists

      # Initialize a structure-aware splitter
      #
      # @param max_tokens [Integer] maximum tokens per chunk
      # @param overlap_tokens [Integer] number of tokens to overlap between chunks
      # @param tokenizer [Symbol, Tokenizers::Base] tokenizer to use
      # @param preserve_code_blocks [Boolean] whether to keep code blocks intact
      # @param preserve_lists [Boolean] whether to keep lists intact
      def initialize(max_tokens: 512, overlap_tokens: 0, tokenizer: :gpt4,
                     preserve_code_blocks: true, preserve_lists: true, **options)
        super(max_tokens: max_tokens, overlap_tokens: overlap_tokens, tokenizer: tokenizer, **options)
        @preserve_code_blocks = preserve_code_blocks
        @preserve_lists = preserve_lists
      end

      # Split text while preserving structure
      #
      # @param text [String] the text to split
      # @return [Array<Chunk>] array of text chunks
      def perform_split(text)
        return [] if text.nil? || text.empty?

        if Kaito::Utils::TextUtils.markdown?(text)
          split_markdown(text)
        elsif Kaito::Utils::TextUtils.code?(text)
          split_code(text)
        else
          # Fall back to semantic splitting
          Splitters::Semantic.new(
            max_tokens: max_tokens,
            overlap_tokens: overlap_tokens,
            tokenizer: tokenizer
          ).split(text)
        end
      end

      private

      def split_markdown(text)
        sections = extract_markdown_sections(text)
        combine_sections(sections)
      end

      def extract_markdown_sections(text)
        sections = []
        current_section = { header: nil, level: 0, content: [], start_line: 0 }
        lines = text.split("\n")

        lines.each_with_index do |line, index|
          if (match = line.match(/^(\#{1,6})\s+(.+)$/))
            sections = finalize_and_add_section(sections, current_section)
            current_section = start_new_section(match, index)
          elsif preserve_code_blocks && line.start_with?('```')
            current_section = process_code_block(lines, index, current_section)
          else
            current_section[:content] << line
          end
        end

        finalize_and_add_section(sections, current_section)
      end

      def start_new_section(match, index)
        {
          header: match[2],
          level: match[1].length,
          content: [],
          start_line: index
        }
      end

      def finalize_and_add_section(sections, section)
        return sections if section[:content].empty? && section[:header].nil?

        section[:content] = section[:content].join("\n")
        sections << section
        sections
      end

      def process_code_block(lines, start_index, current_section)
        current_section[:content] << lines[start_index]
        index = start_index + 1

        while index < lines.length && !lines[index].start_with?('```')
          current_section[:content] << lines[index]
          index += 1
        end

        current_section[:content] << lines[index] if index < lines.length
        current_section
      end

      def combine_sections(sections)
        return [] if sections.empty?

        chunks = []
        current_group = []
        current_tokens = 0

        sections.each do |section|
          section_text = format_section(section)
          section_tokens = tokenizer.count(section_text)

          if section_tokens > max_tokens
            chunks, current_group, current_tokens = handle_oversized_section(
              section, chunks, current_group, current_tokens
            )
            next
          end

          if should_flush_current_group?(current_tokens, section_tokens, current_group)
            chunks, current_group, current_tokens = flush_and_overlap(chunks, current_group)
          end

          current_group << section
          current_tokens += section_tokens
        end

        chunks << create_chunk_from_sections(current_group, chunks.length) unless current_group.empty?
        chunks
      end

      def handle_oversized_section(section, chunks, current_group, current_tokens)
        unless current_group.empty?
          chunks << create_chunk_from_sections(current_group, chunks.length)
          current_group = []
          current_tokens = 0
        end

        split_large_section(section).each { |chunk| chunks << chunk }
        [chunks, current_group, current_tokens]
      end

      def should_flush_current_group?(current_tokens, section_tokens, current_group)
        (current_tokens + section_tokens > max_tokens) && !current_group.empty?
      end

      def flush_and_overlap(chunks, current_group)
        chunks << create_chunk_from_sections(current_group, chunks.length)

        if overlap_tokens.positive?
          overlap_group = calculate_overlap_sections(current_group)
          current_tokens = overlap_group.sum { |s| tokenizer.count(format_section(s)) }
          [chunks, overlap_group, current_tokens]
        else
          [chunks, [], 0]
        end
      end

      def format_section(section)
        if section[:header]
          header = "#{'#' * section[:level]} #{section[:header]}"
          "#{header}\n\n#{section[:content]}"
        else
          section[:content]
        end
      end

      def create_chunk_from_sections(sections, index)
        text = sections.map { |s| format_section(s) }.join("\n\n")

        metadata = {
          index: index,
          section_count: sections.length,
          structure: {
            headers: sections.map { |s| s[:header] }.compact,
            levels: sections.map { |s| s[:level] }
          }
        }

        Chunk.new(text, metadata: metadata, token_count: tokenizer.count(text))
      end

      def calculate_overlap_sections(sections)
        return [] if overlap_tokens.zero? || sections.empty?

        overlap_secs = []
        tokens = 0

        sections.reverse_each do |section|
          section_text = format_section(section)
          section_tokens = tokenizer.count(section_text)

          break unless tokens + section_tokens <= overlap_tokens

          overlap_secs.unshift(section)
          tokens += section_tokens
        end

        overlap_secs
      end

      def split_large_section(section)
        format_section(section)

        # Use semantic splitter for large sections
        semantic_splitter = Splitters::Semantic.new(
          max_tokens: max_tokens,
          overlap_tokens: 0,
          tokenizer: tokenizer
        )

        chunks = semantic_splitter.split(section[:content])

        # Add header metadata to each chunk
        chunks.map.with_index do |chunk, idx|
          metadata = chunk.metadata.merge(
            structure: {
              header: section[:header],
              level: section[:level],
              sub_chunk: idx
            }
          )

          Chunk.new(chunk.text, metadata: metadata, token_count: chunk.token_count)
        end
      end

      def split_code(text)
        # For code, try to split by function/class boundaries
        lines = text.split("\n")
        blocks = extract_code_blocks(lines)
        combine_code_blocks(blocks)
      end

      def extract_code_blocks(lines)
        blocks = []
        current_block = []
        indent_level = 0

        lines.each do |line|
          current_indent = line[/^\s*/].length

          # Detect potential block boundaries (functions, classes, etc.)
          if line.match?(/^\s*(def|class|module|function|const|let|var|public|private|protected)\s/)
            # Save previous block
            blocks << current_block.join("\n") unless current_block.empty?
            current_block = [line]
            indent_level = current_indent
          else
            current_block << line
          end
        end

        blocks << current_block.join("\n") unless current_block.empty?
        blocks
      end

      def combine_code_blocks(blocks)
        semantic_splitter = Splitters::Semantic.new(
          max_tokens: max_tokens,
          overlap_tokens: overlap_tokens,
          tokenizer: tokenizer,
          preserve_sentences: false
        )

        all_chunks = []
        blocks.each do |block|
          chunks = semantic_splitter.split(block)
          all_chunks.concat(chunks)
        end

        # Re-index chunks by creating new chunk objects
        reindex_chunks(all_chunks)
      end
    end
  end
end
