# frozen_string_literal: true

module ParseHelper
  include AST::Sexp
  ALL_VERSIONS = %w[1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 3.0 3.1 3.2 mac ios]

  KNOWN_FAILURES = [
    # Skipping this for now until https://github.com/ruby/ruby/pull/5801 is
    # merged. At that point we'll want to support the more recent ripper events
    # in Syntax Tree and then also find a way to support older versions.
    "test_send_lambda_args_shadow",

    # I think this may be a bug in the parser gem's precedence calculation.
    # Unary plus appears to be parsed as part of the number literal in CRuby,
    # but parser is parsing it as a separate operator.
    "test_unary_num_pow_precedence"
  ]

  private

  def assert_context(*); end
  def assert_diagnoses(*); end
  def assert_diagnoses_many(*); end
  def refute_diagnoses(*); end
  def with_versions(*); end

  def assert_parses(ast, code, source_maps = "", versions = ALL_VERSIONS)
    # Skip a set list of tests since we know they are expected to fail.
    return if KNOWN_FAILURES.include?(caller[0][/`(.+)'/, 1])

    # Skip any examples that don't include 3.2 since we're not trying to test
    # older versions.
    return unless versions.include?("3.2")

    expected = parse(code)
    return if expected.nil?

    visitor = SyntaxTree::Translator::Parser.new("(string)", 1)
    actual = visitor.visit(SyntaxTree.parse(code))
    assert_equal(expected, actual)
  end

  def parse(code)
    # Skip parsing if any of the non-default options are set.
    %i[lambda procarg0 encoding arg_inside_procarg0 forward_arg kwargs match_pattern].each do |option|
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
