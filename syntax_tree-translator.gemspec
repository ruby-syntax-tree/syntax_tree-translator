# frozen_string_literal: true

require_relative "lib/syntax_tree/translator/version"

Gem::Specification.new do |spec|
  spec.name          = "syntax_tree-translator"
  spec.version       = SyntaxTree::Translator::VERSION
  spec.authors       = ["Kevin Newton"]
  spec.email         = ["kddnewton@gmail.com"]

  spec.summary       = "Translate Syntax Tree into other representations"
  spec.homepage      = "https://github.com/kddnewton/syntax_tree-translator"
  spec.license       = "MIT"
  spec.metadata      = { "rubygems_mfa_required" => "true" }

  spec.files         = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]

  spec.add_dependency "parser"
  spec.add_dependency "rubocop-ast"
  spec.add_dependency "ruby_parser"
  spec.add_dependency "syntax_tree", ">= 2.7.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "simplecov"
end
