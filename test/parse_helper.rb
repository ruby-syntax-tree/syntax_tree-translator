# frozen_string_literal: true

module ParseHelper
  include AST::Sexp
  ALL_VERSIONS = []

  private

  def assert_context(*); end
  def assert_diagnoses(*); end
  def assert_diagnoses_many(*); end
  def refute_diagnoses(*); end
  def with_versions(*); end

  def assert_parses(ast, code, source_maps = "", versions = ALL_VERSIONS)
    expected = parse(code)
    return if expected.nil?

    visitor = SyntaxTree::ParserTranslator.new("(string)", 1)
    actual = visitor.visit(SyntaxTree.parse(code))
    assert_equal(expected, actual)
  end

  def parse(code)
    parser = Parser::CurrentRuby.default_parser
    parser.diagnostics.consumer = ->(*) {}

    buffer = Parser::Source::Buffer.new("(string)", 1)
    buffer.source = code

    parser.parse(buffer)
  rescue Parser::SyntaxError
  end
end
