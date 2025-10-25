# frozen_string_literal: true

require_relative "lib/kaito/version"

Gem::Specification.new do |spec|
  spec.name = "kaito"
  spec.version = Kaito::VERSION
  spec.authors = ["Magnus Fremont"]
  spec.email = ["your.email@example.com"] # TODO: Update with your email

  spec.summary = "Production-grade text splitting for LLM applications"
  spec.description = <<~DESC
    Kaito is a high-performance, intelligent text splitting library for Ruby designed specifically
    for LLM applications. It provides token-aware chunking, semantic boundary preservation,
    multilingual support, and streaming capabilities that surpass existing solutions like Baran
    and LangChain.
  DESC
  spec.homepage = "https://github.com/yourusername/kaito" # TODO: Update with your GitHub username
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/kaito"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "tiktoken_ruby", "~> 0.0.6"
  spec.add_dependency "pragmatic_segmenter", "~> 0.3.23"
  spec.add_dependency "unicode_utils", "~> 1.4"
  spec.add_dependency "thor", "~> 1.3"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-rspec", "~> 2.20"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "benchmark-ips", "~> 2.12"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
