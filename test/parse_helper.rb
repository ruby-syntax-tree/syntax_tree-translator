# frozen_string_literal: true

module ParseHelper
  include AST::Sexp
  ALL_VERSIONS = %w[1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 3.0 3.1 3.2 mac ios]

  KNOWN_FAILURES = [
    # I think this may be a bug in the parser gem's precedence calculation.
    # Unary plus appears to be parsed as part of the number literal in CRuby,
    # but parser is parsing it as a separate operator.
    "test_unary_num_pow_precedence:3504",

    # Not much to be done about this. Basically, regular expressions with named
    # capture groups that use the =~ operator inject local variables into the
    # current scope. In the parser gem, it detects this and changes future
    # references to that name to be a local variable instead of a potential
    # method call. CRuby does not do this.
    "test_lvar_injecting_match:3777",

    # This is failing because CRuby is not marking values captured in hash
    # patterns as local variables, while the parser gem is.
    "test_pattern_matching_hash:8970",

    # This is not actually allowed in the CRuby parser but the parser gem thinks
    # it is allowed.
    "test_pattern_matching_hash_with_string_keys:9015",
    "test_pattern_matching_hash_with_string_keys:9026",
    "test_pattern_matching_hash_with_string_keys:9037",
    "test_pattern_matching_hash_with_string_keys:9059",
    "test_pattern_matching_hash_with_string_keys:9070",
    "test_pattern_matching_hash_with_string_keys:9081",

    # This happens with pattern matching where you're matching a literal value
    # inside parentheses, which doesn't really do anything. Ripper doesn't
    # capture that this value is inside a parentheses, so it's hard to translate
    # properly.
    "test_pattern_matching_expr_in_paren:9205",

    # These are also failing because of CRuby not marking values captured in
    # hash patterns as local variables.
    "test_pattern_matching_single_line_allowed_omission_of_parentheses:9205",
    "test_pattern_matching_single_line_allowed_omission_of_parentheses:9580",
    "test_pattern_matching_single_line_allowed_omission_of_parentheses:9610",

    # I'm not even sure what this is testing, because the code is invalid in
    # CRuby.
    "test_control_meta_escape_chars_in_regexp__since_31:*",
  ]

  # These are failures that we need to take care of (or determine the reason
  # that we're not going to handle them).
  TODO_FAILURES = [
    "test_dedenting_heredoc:333",
    "test_dedenting_heredoc:389",
    "test_dedenting_heredoc:398",
    "test_slash_newline_in_heredocs:7193",
    "test_parser_slash_slash_n_escaping_in_literals:*"
  ]

  private

  def assert_context(*); end
  def assert_diagnoses(*); end
  def assert_diagnoses_many(*); end
  def refute_diagnoses(*); end
  def with_versions(*); end

  def assert_parses(ast, code, source_maps = "", versions = ALL_VERSIONS)
    # Skip any examples that don't include 3.2 since we're not trying to test
    # older versions.
    return unless versions.include?("3.2")

    caller(1, 3).each do |line|
      _, lineno, name = *line.match(/(\d+):in `(.+)'/)

      # Return directly and don't do anything if it's a known failure.
      return if KNOWN_FAILURES.include?("#{name}:#{lineno}")
      return if KNOWN_FAILURES.include?("#{name}:*")

      # Report a skipped test if it's a known todo failure.
      skip if TODO_FAILURES.include?("#{name}:#{lineno}")
      skip if TODO_FAILURES.include?("#{name}:*")
    end

    expected = parse(code)
    return if expected.nil?

    buffer = Parser::Source::Buffer.new("(string)")
    buffer.source = code

    visitor = SyntaxTree::Translator::Parser.new(buffer)
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
