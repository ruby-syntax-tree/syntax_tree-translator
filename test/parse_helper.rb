# frozen_string_literal: true

module ParseHelper
  include AST::Sexp
  ALL_VERSIONS = %w[1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 3.0 3.1 3.2 mac ios]

  private

  def assert_context(*); end
  def assert_diagnoses(*); end
  def assert_diagnoses_many(*); end
  def refute_diagnoses(*); end
  def with_versions(*); end

  def assert_parses(ast, code, source_maps = "", versions = ALL_VERSIONS)
    return unless versions.include?("3.2")

    expected = parse(code)
    return if expected.nil?

    visitor = SyntaxTree::ParserTranslator.new("(string)", 1)
    actual = visitor.visit(SyntaxTree.parse(code))
    assert_equal(expected, actual)
  end

  def parse(code)
    # Skip parsing if any of the non-default options are set.
    %i[lambda procarg0 encoding index arg_inside_procarg0 forward_arg kwargs match_pattern].each do |option|
      return unless Parser::Builders::Default.public_send(:"emit_#{option}")
    end

    parser = Parser::CurrentRuby.default_parser
    parser.diagnostics.consumer = ->(*) {}

    buffer = Parser::Source::Buffer.new("(string)", 1)
    buffer.source = code

    parser.parse(buffer)
  rescue Parser::SyntaxError
  end
end
