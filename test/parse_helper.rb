# frozen_string_literal: true

module ParseHelper
  include AST::Sexp
  ALL_VERSIONS = []

  private

  def assert_context(*); end
  def assert_diagnoses(*); end
  def refute_diagnoses(*); end
  def with_versions(*); end

  def assert_parses(ast, code, source_maps = "", versions = ALL_VERSIONS)
    expected = Parser::CurrentRuby.parse(code)
    actual = SyntaxTree::ParserTranslator.new.visit(SyntaxTree.parse(code))

    assert_equal(expected, actual)
  end
end
