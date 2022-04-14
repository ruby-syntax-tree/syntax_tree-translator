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
    filename = "(string)"
    expected = parse(filename, code)
    return if expected.nil?

    visitor = SyntaxTree::ParserTranslator.new(filename)
    actual = visitor.visit(SyntaxTree.parse(code))
    assert_equal(expected, actual)
  end

  def parse(filename, code)
    parser = Parser::CurrentRuby.default_parser
    parser.diagnostics.consumer = ->(*) {}

    buffer = Parser::Source::Buffer.new(filename, 1)
    buffer.source = code

    parser.parse(buffer)
  rescue Parser::SyntaxError
  end
end
