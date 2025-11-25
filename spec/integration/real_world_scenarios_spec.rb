# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'benchmark'

RSpec.describe 'Real World Scenarios Integration Tests' do
  # Test fixtures for different document types
  let(:markdown_document) do
    <<~MARKDOWN
      # Introduction to Machine Learning

      Machine learning is a subset of artificial intelligence that enables systems to learn and improve from experience.

      ## Supervised Learning

      Supervised learning algorithms learn from labeled training data. The model is trained on input-output pairs.

      ### Classification
      Classification algorithms predict discrete categories. Examples include:
      - Logistic Regression
      - Decision Trees
      - Random Forests
      - Neural Networks

      ### Regression
      Regression algorithms predict continuous values. Common techniques include:
      - Linear Regression
      - Polynomial Regression
      - Support Vector Regression

      ## Unsupervised Learning

      Unsupervised learning finds patterns in unlabeled data. Key approaches:

      ### Clustering
      Grouping similar data points together:
      - K-Means
      - DBSCAN
      - Hierarchical Clustering

      ### Dimensionality Reduction
      Reducing the number of features:
      - PCA (Principal Component Analysis)
      - t-SNE
      - UMAP

      ## Deep Learning

      Deep learning uses neural networks with multiple layers to learn complex patterns.

      ```python
      import tensorflow as tf

      model = tf.keras.Sequential([
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(10, activation='softmax')
      ])
      ```

      ## Conclusion

      Machine learning continues to evolve, enabling new applications across industries.
    MARKDOWN
  end

  let(:code_document) do
    <<~RUBY
      # frozen_string_literal: true

      module DataProcessing
        # Main processor class for handling data transformations
        class Processor
          attr_reader :data, :transformations

          def initialize(data)
            @data = data
            @transformations = []
          end

          # Add a transformation to the pipeline
          # @param transform [Proc] the transformation to apply
          def add_transformation(transform)
            raise ArgumentError, 'Transform must be callable' unless transform.respond_to?(:call)
            @transformations << transform
            self
          end

          # Execute all transformations in order
          # @return [Array] transformed data
          def process
            result = @data.dup
            @transformations.each do |transform|
              result = transform.call(result)
            end
            result
          end

          # Clear all transformations
          def reset
            @transformations.clear
            self
          end
        end

        # Filter operations
        module Filters
          def self.remove_nulls
            ->(data) { data.compact }
          end

          def self.remove_duplicates
            ->(data) { data.uniq }
          end

          def self.filter_by(condition)
            ->(data) { data.select { |item| condition.call(item) } }
          end
        end

        # Transformation operations
        module Transformations
          def self.map_values(&block)
            ->(data) { data.map(&block) }
          end

          def self.normalize
            ->(data) {
              min = data.min
              max = data.max
              range = max - min
              data.map { |v| (v - min) / range.to_f }
            }
          end
        end
      end
    RUBY
  end

  let(:plain_text_document) do
    <<~TEXT
      Artificial intelligence has revolutionized the way we approach problem-solving in the 21st century. From healthcare diagnostics to autonomous vehicles, AI systems are becoming increasingly sophisticated and integrated into our daily lives.

      The foundation of modern AI rests on machine learning algorithms that can identify patterns in vast amounts of data. These algorithms don't follow explicit programming instructions; instead, they learn from examples and experience. This fundamental shift from rule-based programming to learning-based systems has opened up possibilities that were previously unimaginable.

      Natural language processing represents one of the most exciting frontiers in AI. The ability to understand, interpret, and generate human language has led to breakthroughs in translation services, content creation, and conversational interfaces. Large language models can now engage in nuanced discussions, write creative content, and even assist with complex reasoning tasks.

      Computer vision has similarly transformed numerous industries. Modern vision systems can detect objects, recognize faces, analyze medical images, and navigate complex environments. The combination of deep learning and massive datasets has pushed the boundaries of what machines can "see" and understand from visual information.

      However, the rapid advancement of AI technology also raises important ethical considerations. Questions about bias in algorithms, privacy concerns, job displacement, and the need for transparency in AI decision-making are crucial discussions that society must address. As AI systems become more powerful and autonomous, ensuring they align with human values becomes increasingly important.

      The future of AI promises even more transformative changes. Researchers are working on artificial general intelligence that could match or exceed human cognitive abilities across a wide range of tasks. While this goal remains distant, the incremental progress in specialized AI applications continues to deliver real-world value and reshape how we work, communicate, and solve problems.
    TEXT
  end

  let(:large_document) do
    # Create a document > 1MB for performance testing
    base_content = plain_text_document + markdown_document + code_document
    (base_content * 200) + ("\n" + "Additional padding content. " * 5000)
  end

  describe 'RAG Pipeline Integration' do
    context 'loading and chunking documents' do
      it 'processes markdown documents with optimal settings for embedding' do
        chunks = Kaito.split(
          markdown_document,
          strategy: :structure_aware,
          max_tokens: 512,
          overlap_tokens: 50,
          tokenizer: :gpt4
        )

        expect(chunks).not_to be_empty
        expect(chunks).to all(be_a(Kaito::Chunk))

        # Verify all chunks are within token limits suitable for embeddings
        chunks.each do |chunk|
          expect(chunk.token_count).to be > 0
          expect(chunk.token_count).to be <= 512
          expect(chunk.text).not_to be_empty
          expect(chunk.text.strip).not_to be_empty
        end

        # Verify semantic boundaries are preserved (no mid-sentence breaks in well-formed text)
        text_chunks = chunks.select { |c| c.text.length > 20 }
        expect(text_chunks).not_to be_empty
      end

      it 'processes code documents maintaining semantic coherence' do
        chunks = Kaito.split(
          code_document,
          strategy: :structure_aware,
          max_tokens: 300,
          overlap_tokens: 30,
          tokenizer: :gpt4
        )

        expect(chunks).not_to be_empty

        chunks.each do |chunk|
          expect(chunk.token_count).to be <= 300
          # Code chunks should have reasonable content
          expect(chunk.text.strip.length).to be > 0
        end

        # Structure awareness should preserve class/method boundaries where possible
        combined_text = chunks.map(&:text).join
        expect(combined_text).to include('class Processor')
        expect(combined_text).to include('def initialize')
      end

      it 'processes plain text documents with semantic splitting' do
        chunks = Kaito.split(
          plain_text_document,
          strategy: :semantic,
          max_tokens: 400,
          overlap_tokens: 40,
          tokenizer: :gpt4
        )

        expect(chunks).not_to be_empty

        chunks.each do |chunk|
          expect(chunk.token_count).to be <= 400
          # Semantic splitter should respect sentence boundaries
          # Most chunks should end with proper punctuation
          text = chunk.text.strip
          expect(text).not_to be_empty
        end
      end
    end

    context 'verifying chunk quality for embeddings' do
      it 'ensures chunks have appropriate token counts' do
        # Test with different target sizes common in embedding models
        [256, 512, 1024].each do |target_size|
          chunks = Kaito.split(
            markdown_document,
            strategy: :semantic,
            max_tokens: target_size,
            tokenizer: :gpt4
          )

          chunks.each do |chunk|
            expect(chunk.token_count).to be <= target_size
            # Chunks should be substantial enough for meaningful embeddings
            expect(chunk.token_count).to be > 0
          end
        end
      end

      it 'maintains semantic coherence across chunks' do
        chunks = Kaito.split(
          plain_text_document,
          strategy: :semantic,
          max_tokens: 300,
          overlap_tokens: 50,
          tokenizer: :gpt4
        )

        expect(chunks.length).to be >= 2

        # Check overlap exists between consecutive chunks
        (0...chunks.length - 1).each do |i|
          chunk1 = chunks[i]
          chunk2 = chunks[i + 1]

          # Both chunks should have content
          expect(chunk1.text.strip).not_to be_empty
          expect(chunk2.text.strip).not_to be_empty
        end
      end

      it 'handles different document types appropriately' do
        document_types = {
          markdown: markdown_document,
          code: code_document,
          plain_text: plain_text_document
        }

        document_types.each do |type, content|
          chunks = Kaito.split(
            content,
            strategy: :structure_aware,
            max_tokens: 400,
            tokenizer: :gpt4
          )

          expect(chunks).not_to be_empty
          chunks.each do |chunk|
            expect(chunk.token_count).to be <= 400
            expect(chunk.metadata).to include(:index)
          end
        end
      end
    end
  end

  describe 'Vector Database Integration Examples' do
    context 'Pinecone-style chunking' do
      it 'produces chunks with compatible metadata structure' do
        chunks = Kaito.split(
          markdown_document,
          strategy: :semantic,
          max_tokens: 512,
          overlap_tokens: 50,
          tokenizer: :gpt4
        )

        # Verify chunks can be easily converted to Pinecone format
        pinecone_records = chunks.map do |chunk|
          {
            id: "chunk_#{chunk.index}",
            values: [], # Would be filled by embedding model
            metadata: {
              text: chunk.text,
              token_count: chunk.token_count,
              index: chunk.index
            }
          }
        end

        expect(pinecone_records).not_to be_empty
        pinecone_records.each do |record|
          expect(record).to include(:id, :values, :metadata)
          expect(record[:metadata]).to include(:text, :token_count, :index)
        end
      end

      it 'handles batch processing for vector upsert' do
        chunks = Kaito.split(
          large_document[0..50_000], # Use subset for faster testing
          strategy: :semantic,
          max_tokens: 512,
          overlap_tokens: 50,
          tokenizer: :gpt4
        )

        # Simulate batching for Pinecone (max 100 vectors per upsert)
        batch_size = 100
        batches = chunks.each_slice(batch_size).to_a

        expect(batches).not_to be_empty
        batches.each do |batch|
          expect(batch.length).to be <= batch_size
          batch.each do |chunk|
            expect(chunk).to be_a(Kaito::Chunk)
            expect(chunk.token_count).to be <= 512
          end
        end
      end
    end

    context 'Chroma-style chunking' do
      it 'produces chunks with compatible metadata format' do
        chunks = Kaito.split(
          code_document,
          strategy: :structure_aware,
          max_tokens: 400,
          tokenizer: :gpt4
        )

        # Verify chunks can be converted to Chroma format
        chroma_records = chunks.map do |chunk|
          {
            documents: [chunk.text],
            metadatas: [{
              index: chunk.index,
              token_count: chunk.token_count,
              source: 'code_document'
            }],
            ids: ["doc_#{chunk.index}"]
          }
        end

        expect(chroma_records).not_to be_empty
        chroma_records.each do |record|
          expect(record[:documents].first).to be_a(String)
          expect(record[:metadatas].first).to be_a(Hash)
          expect(record[:ids].first).to match(/doc_\d+/)
        end
      end
    end

    context 'Qdrant-style chunking' do
      it 'produces chunks with compatible payload format' do
        chunks = Kaito.split(
          markdown_document,
          strategy: :structure_aware,
          max_tokens: 512,
          tokenizer: :gpt4
        )

        # Verify chunks can be converted to Qdrant format
        qdrant_points = chunks.map.with_index do |chunk, idx|
          {
            id: idx,
            vector: [], # Would be filled by embedding model
            payload: {
              text: chunk.text,
              token_count: chunk.token_count,
              chunk_index: chunk.index,
              metadata: chunk.metadata
            }
          }
        end

        expect(qdrant_points).not_to be_empty
        qdrant_points.each do |point|
          expect(point).to include(:id, :vector, :payload)
          expect(point[:payload]).to include(:text, :token_count, :chunk_index)
        end
      end
    end
  end

  describe 'Full Workflow Examples' do
    context 'complete document processing pipeline' do
      it 'processes document from loading to embedding-ready chunks' do
        # Step 1: Load document
        document = markdown_document

        # Step 2: Count tokens to determine strategy
        total_tokens = Kaito.count_tokens(document, tokenizer: :gpt4)
        expect(total_tokens).to be > 0

        # Step 3: Split with appropriate strategy
        chunks = Kaito.split(
          document,
          strategy: :structure_aware,
          max_tokens: 512,
          overlap_tokens: 50,
          tokenizer: :gpt4
        )

        # Step 4: Validate chunks
        expect(chunks).not_to be_empty
        chunks.each do |chunk|
          expect(chunk.token_count).to be <= 512
          expect(chunk.text.strip).not_to be_empty
        end

        # Step 5: Prepare for embedding (simulate)
        embedding_ready = chunks.map do |chunk|
          {
            text: chunk.text,
            metadata: chunk.metadata.merge(
              total_tokens: total_tokens,
              chunk_count: chunks.length
            )
          }
        end

        expect(embedding_ready.length).to eq(chunks.length)
      end

      it 'handles full RAG pipeline workflow' do
        # Simulate a complete RAG workflow
        documents = {
          'guide.md' => markdown_document,
          'processor.rb' => code_document,
          'article.txt' => plain_text_document
        }

        all_chunks = []

        documents.each do |filename, content|
          chunks = Kaito.split(
            content,
            strategy: :structure_aware,
            max_tokens: 400,
            overlap_tokens: 40,
            tokenizer: :gpt4
          )

          # Add source file to metadata
          chunks_with_source = chunks.map do |chunk|
            Kaito::Chunk.new(
              chunk.text,
              metadata: chunk.metadata.merge(source_file: filename),
              token_count: chunk.token_count
            )
          end

          all_chunks.concat(chunks_with_source)
        end

        expect(all_chunks.length).to be >= 3
        all_chunks.each do |chunk|
          expect(chunk.source_file).to match(/\.(md|rb|txt)$/)
          expect(chunk.token_count).to be <= 400
        end
      end
    end

    context 'batch processing multiple files' do
      it 'processes multiple documents efficiently' do
        documents = [
          markdown_document,
          code_document,
          plain_text_document
        ]

        results = documents.map do |doc|
          Kaito.split(
            doc,
            strategy: :semantic,
            max_tokens: 300,
            overlap_tokens: 30,
            tokenizer: :gpt4
          )
        end

        expect(results.length).to eq(3)
        results.each do |chunks|
          expect(chunks).to be_an(Array)
          expect(chunks).not_to be_empty
        end

        total_chunks = results.flatten
        expect(total_chunks.length).to be >= 3
      end

      it 'handles streaming for large file batches' do
        # Create temporary test files
        temp_files = []

        begin
          3.times do |i|
            file = Tempfile.new(["test_doc_#{i}", '.txt'])
            file.write(plain_text_document)
            file.close
            temp_files << file
          end

          # Stream process each file
          all_chunks = []
          temp_files.each do |file|
            chunks = []
            Kaito.stream_file(
              file.path,
              strategy: :semantic,
              max_tokens: 400,
              tokenizer: :gpt4
            ) do |chunk|
              chunks << chunk
            end
            all_chunks.concat(chunks)
          end

          expect(all_chunks.length).to be >= 3
          all_chunks.each do |chunk|
            expect(chunk).to be_a(Kaito::Chunk)
          end
        ensure
          temp_files.each(&:unlink)
        end
      end
    end

    context 'comparing different splitter strategies' do
      it 'compares strategies on same document' do
        strategies = [:character, :semantic, :structure_aware, :recursive, :adaptive]
        document = markdown_document

        results = {}

        strategies.each do |strategy|
          chunks = Kaito.split(
            document,
            strategy: strategy,
            max_tokens: 400,
            overlap_tokens: 40,
            tokenizer: :gpt4
          )

          results[strategy] = {
            chunk_count: chunks.length,
            avg_tokens: chunks.sum(&:token_count) / chunks.length.to_f,
            total_tokens: chunks.sum(&:token_count)
          }
        end

        expect(results.keys).to match_array(strategies)
        results.each do |strategy, stats|
          expect(stats[:chunk_count]).to be > 0
          expect(stats[:avg_tokens]).to be > 0
          expect(stats[:total_tokens]).to be > 0
        end
      end

      it 'identifies optimal strategy for document type' do
        test_cases = {
          markdown: { document: markdown_document, optimal: :structure_aware },
          code: { document: code_document, optimal: :structure_aware },
          plain_text: { document: plain_text_document, optimal: :semantic }
        }

        test_cases.each do |doc_type, config|
          chunks = Kaito.split(
            config[:document],
            strategy: config[:optimal],
            max_tokens: 400,
            tokenizer: :gpt4
          )

          expect(chunks).not_to be_empty
          chunks.each do |chunk|
            expect(chunk.token_count).to be <= 400
          end
        end
      end
    end
  end

  describe 'Performance and Memory Tests' do
    context 'processing large files' do
      it 'handles 1MB+ documents without memory issues' do
        # Large document is ~1.5MB
        expect(large_document.bytesize).to be > 1_000_000

        chunks = nil
        memory_before = GC.stat[:total_allocated_objects]

        chunks = Kaito.split(
          large_document,
          strategy: :semantic,
          max_tokens: 512,
          overlap_tokens: 50,
          tokenizer: :gpt4
        )

        memory_after = GC.stat[:total_allocated_objects]
        memory_used = memory_after - memory_before

        expect(chunks).not_to be_empty
        expect(chunks.length).to be > 50
        # Memory usage should be reasonable (adjust threshold as needed)
        # For a 1MB+ document, 5M allocated objects is acceptable
        expect(memory_used).to be < 5_000_000
      end

      it 'streams large files efficiently' do
        file = Tempfile.new('large_test.txt')
        begin
          file.write(large_document)
          file.close

          chunk_count = 0
          Kaito.stream_file(
            file.path,
            strategy: :semantic,
            max_tokens: 512,
            tokenizer: :gpt4
          ) do |chunk|
            chunk_count += 1
            expect(chunk.token_count).to be <= 512
          end

          expect(chunk_count).to be > 50
        ensure
          file.unlink
        end
      end
    end

    context 'comparing memory usage of different splitters' do
      it 'measures memory footprint across strategies' do
        document = markdown_document * 10 # Medium-sized document

        strategies = [:character, :semantic, :structure_aware]
        memory_usage = {}

        strategies.each do |strategy|
          GC.start
          memory_before = GC.stat[:total_allocated_objects]

          Kaito.split(
            document,
            strategy: strategy,
            max_tokens: 400,
            tokenizer: :gpt4
          )

          memory_after = GC.stat[:total_allocated_objects]
          memory_usage[strategy] = memory_after - memory_before
        end

        # All strategies should have reasonable memory usage
        memory_usage.each do |strategy, usage|
          expect(usage).to be > 0
          expect(usage).to be < 500_000
        end
      end
    end

    context 'benchmarking different strategies' do
      it 'measures performance of each strategy' do
        document = plain_text_document * 5
        strategies = [:character, :semantic, :structure_aware, :recursive, :adaptive]

        benchmarks = {}

        strategies.each do |strategy|
          time = Benchmark.measure do
            Kaito.split(
              document,
              strategy: strategy,
              max_tokens: 400,
              overlap_tokens: 40,
              tokenizer: :gpt4
            )
          end

          benchmarks[strategy] = time.real
        end

        # All strategies should complete in reasonable time
        benchmarks.each do |strategy, duration|
          expect(duration).to be < 5.0 # Should complete within 5 seconds
        end

        # Character splitting should be fastest
        expect(benchmarks[:character]).to be < benchmarks.values.max
      end

      it 'benchmarks token counting performance' do
        document = plain_text_document * 10

        time = Benchmark.measure do
          100.times do
            Kaito.count_tokens(document, tokenizer: :gpt4)
          end
        end

        # Should handle 100 token counts quickly
        expect(time.real).to be < 10.0
      end
    end
  end

  describe 'Real Document Examples' do
    context 'processing project README' do
      let(:readme_path) { File.join(__dir__, '../../README.md') }

      it 'processes the actual project README' do
        skip 'README not found' unless File.exist?(readme_path)

        readme_content = File.read(readme_path)
        expect(readme_content).not_to be_empty

        chunks = Kaito.split(
          readme_content,
          strategy: :structure_aware,
          max_tokens: 512,
          overlap_tokens: 50,
          tokenizer: :gpt4
        )

        expect(chunks).not_to be_empty
        chunks.each do |chunk|
          expect(chunk.token_count).to be <= 512
          expect(chunk.text.strip).not_to be_empty
        end

        # Should preserve markdown structure
        expect(chunks.any? { |c| c.text.include?('#') }).to be true
      end

      it 'compares different chunking strategies on README' do
        skip 'README not found' unless File.exist?(readme_path)

        readme_content = File.read(readme_path)
        strategies = [:semantic, :structure_aware, :recursive]

        results = strategies.map do |strategy|
          chunks = Kaito.split(
            readme_content,
            strategy: strategy,
            max_tokens: 512,
            tokenizer: :gpt4
          )
          [strategy, chunks.length]
        end.to_h

        expect(results.values).to all(be > 0)
      end
    end

    context 'processing example code files' do
      let(:examples_dir) { File.join(__dir__, '../../examples') }

      it 'processes Ruby example files' do
        skip 'Examples directory not found' unless Dir.exist?(examples_dir)

        ruby_files = Dir.glob(File.join(examples_dir, '*.rb'))
        skip 'No Ruby files found' if ruby_files.empty?

        ruby_files.first(2).each do |file_path|
          content = File.read(file_path)
          next if content.strip.empty?

          chunks = Kaito.split(
            content,
            strategy: :structure_aware,
            max_tokens: 400,
            tokenizer: :gpt4
          )

          expect(chunks).not_to be_empty
          chunks.each do |chunk|
            expect(chunk.token_count).to be <= 400
          end
        end
      end

      it 'processes example text documents' do
        skip 'Examples directory not found' unless Dir.exist?(examples_dir)

        text_files = Dir.glob(File.join(examples_dir, '*.txt'))
        skip 'No text files found' if text_files.empty?

        text_files.first(2).each do |file_path|
          content = File.read(file_path)
          next if content.strip.empty?

          chunks = Kaito.split(
            content,
            strategy: :semantic,
            max_tokens: 400,
            overlap_tokens: 40,
            tokenizer: :gpt4
          )

          expect(chunks).not_to be_empty
          chunks.each do |chunk|
            expect(chunk.token_count).to be <= 400
          end
        end
      end
    end

    context 'processing mixed content documents' do
      it 'handles documents with markdown and code blocks' do
        mixed_content = <<~'MIXED'
          # API Documentation

          ## Authentication

          All API requests require authentication using an API key.

          ### Example Code

          ```ruby
          require 'httparty'

          class APIClient
            def initialize(api_key)
              @api_key = api_key
            end

            def get(endpoint)
              HTTParty.get(
                "https://api.example.com/#{endpoint}",
                headers: { 'Authorization' => "Bearer #{@api_key}" }
              )
            end
          end
          ```

          ## Rate Limiting

          The API enforces rate limits to ensure fair usage:
          - 100 requests per minute for free tier
          - 1000 requests per minute for paid tier

          ### Handling Rate Limits

          ```ruby
          response = client.get('users')

          if response.code == 429
            retry_after = response.headers['Retry-After'].to_i
            sleep retry_after
            retry
          end
          ```

          ## Response Format

          All responses are returned in JSON format with the following structure:

          ```json
          {
            "data": {},
            "meta": {
              "status": "success",
              "timestamp": "2024-01-01T00:00:00Z"
            }
          }
          ```
        MIXED

        chunks = Kaito.split(
          mixed_content,
          strategy: :structure_aware,
          max_tokens: 300,
          overlap_tokens: 30,
          tokenizer: :gpt4
        )

        expect(chunks).not_to be_empty
        chunks.each do |chunk|
          expect(chunk.token_count).to be <= 300
        end

        # Should preserve code blocks
        code_chunks = chunks.select { |c| c.text.include?('```') }
        expect(code_chunks).not_to be_empty
      end

      it 'processes technical documentation with formulas and code' do
        technical_doc = <<~TECH
          # Machine Learning Fundamentals

          ## Linear Regression

          Linear regression models the relationship between variables using a linear equation:

          y = mx + b

          Where:
          - y is the predicted value
          - m is the slope
          - x is the input feature
          - b is the y-intercept

          ### Implementation

          ```python
          import numpy as np

          def linear_regression(X, y):
              # Add bias term
              X_b = np.c_[np.ones((len(X), 1)), X]

              # Normal equation: theta = (X^T X)^-1 X^T y
              theta = np.linalg.inv(X_b.T.dot(X_b)).dot(X_b.T).dot(y)

              return theta
          ```

          ### Cost Function

          The cost function for linear regression is Mean Squared Error (MSE):

          MSE = (1/n) * Σ(y_pred - y_actual)^2

          This measures the average squared difference between predictions and actual values.
        TECH

        chunks = Kaito.split(
          technical_doc,
          strategy: :structure_aware,
          max_tokens: 400,
          tokenizer: :gpt4
        )

        expect(chunks).not_to be_empty
        chunks.each do |chunk|
          expect(chunk.token_count).to be <= 400
          expect(chunk.text.strip).not_to be_empty
        end
      end
    end
  end

  describe 'Edge Cases and Error Handling' do
    it 'handles empty documents gracefully' do
      chunks = Kaito.split('', max_tokens: 512)
      expect(chunks).to be_empty
    end

    it 'handles very small documents' do
      tiny_doc = 'Hello, world!'
      chunks = Kaito.split(tiny_doc, max_tokens: 512)

      expect(chunks.length).to eq(1)
      expect(chunks.first.text.strip).to eq(tiny_doc)
    end

    it 'handles documents with special characters' do
      special_doc = "Unicode: 你好 🌍\nEmoji: 😀 🎉\nSymbols: © ® ™"
      chunks = Kaito.split(special_doc, max_tokens: 100)

      expect(chunks).not_to be_empty
      chunks.each do |chunk|
        expect(chunk.text).to match(/[你好🌍😀🎉©®™]/)
      end
    end

    it 'handles documents with inconsistent formatting' do
      messy_doc = "Line1\r\nLine2\nLine3\r\n\r\n\nLine4"
      chunks = Kaito.split(messy_doc, max_tokens: 100)

      expect(chunks).not_to be_empty
      chunks.each do |chunk|
        expect(chunk.text).to be_a(String)
      end
    end
  end
end
