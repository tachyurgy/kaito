# frozen_string_literal: true

require_relative 'lib/kaito/version'

Gem::Specification.new do |spec|
  spec.name = 'kaito'
  spec.version = Kaito::VERSION
  spec.authors = ['Magnus Fremont']
  spec.email = ['magnusfremont@proton.me']

  spec.summary = 'Production-grade text splitting for LLM applications'
  spec.description = <<~DESC
    Kaito is a high-performance, intelligent text splitting library for Ruby designed specifically
    for LLM applications. It provides token-aware chunking with tiktoken_ruby integration, semantic
    boundary preservation, multilingual support, and streaming capabilities. Features include
    multiple splitting strategies (character, semantic, structure-aware, adaptive overlap, recursive),
    intelligent chunk overlap, and a full-featured CLI tool. Perfect for RAG systems and production
    LLM workflows requiring precise token counting and semantic coherence.
  DESC
  spec.homepage = 'https://github.com/tachyurgy/kaito'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['documentation_uri'] = 'https://rubydoc.info/gems/kaito'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # Exclude tests, examples, documentation, and development files
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) ||
        f.start_with?(*%w[
          bin/
          spec/
          test/
          features/
          examples/
          doc/
          coverage/
          .github/
          .yardoc/
        ]) ||
        f.match(%r{^\.}) ||
        f.match(%r{
          \A(
            AUDIT_REPORT\.md|
            IMPLEMENTATION_REVIEW\.md|
            QUICK_FIX_CHECKLIST\.md|
            CLAUDE_TOKENIZER_REMOVAL_SUMMARY\.md|
            blog_.*\.md|
            how-kaito-was-born\.md|
            plan|
            plan2|
            \.rubocop\.yml|
            \.standard\.yml|
            \.rspec|
            \.rspec_status|
            Rakefile|
            Gemfile|
            Gemfile\.lock|
            .*\.gem
          )\z
        }x)
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies with version constraints
  spec.add_dependency 'pragmatic_segmenter', '~> 0.3', '>= 0.3.23'
  spec.add_dependency 'thor', '~> 1.3'
  spec.add_dependency 'tiktoken_ruby', '~> 0.0.6'
  spec.add_dependency 'unicode_utils', '~> 1.4'

  # Development dependencies
  spec.add_development_dependency 'benchmark-ips', '~> 2.12'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'standard', '~> 1.35'
  spec.add_development_dependency 'yard', '~> 0.9'
end
