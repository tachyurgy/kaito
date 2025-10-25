# frozen_string_literal: true

module Kaito
  # Base error class for all Kaito errors
  class Error < StandardError; end

  # Raised when text cannot be split within constraints
  class SplitError < Error; end

  # Raised when tokenization fails
  class TokenizationError < Error; end

  # Raised when configuration is invalid
  class ConfigurationError < Error; end

  # Raised when a file operation fails
  class FileError < Error; end

  # Raised when validation fails
  class ValidationError < Error; end
end
