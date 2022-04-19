# frozen_string_literal: true

require "helper"
require "pt_testcase"

module AssertParse
  class Echo
    ECHO = new

    def method_missing(*)
      ECHO
    end

    def to_ary
      [ECHO, ECHO, ECHO, ECHO]
    end
  end

  def assert_parse(source, parse_tree)
    self.result = Echo::ECHO
    skip if skip?

    parse_tree.deep_each { |sexp| sexp.line ||= 1 }
    parse_tree.line ||= 1

    visitor = SyntaxTree::Translator::RubyParser.new
    self.result = visitor.visit(SyntaxTree.parse(source))

    assert_equal(parse_tree, self.result)
  end

  def assert_equal(expected, actual, message = nil)
    skip if skip?
    super
  end

  private

  def skip?
    caller(1, 10).any? do |line|
      name = line[/`(.+)'/, 1]
      SKIPS.any? { |skip| skip === name }
    end
  end
end

class RubyParserTestCase < ParseTreeTestCase
  def self.inherited(base)
    super if base.name == "TestRubyParserV31"
  end

  def self.method_added(method)
    prepend(AssertParse) if method == :assert_parse
    super
  end
end

module TestRubyParserShared
  def self.method_added(method)
    undef :test_flip2_env_lvar if method == :test_flip2_env_lvar
  end
end

AssertParse::SKIPS = [
  "test___ENCODING__",                                                               
  "test_and_multi",                                                                  
  "test_begin_else_return_value",                                                    
  "test_begin_ensure_no_bodies",                                                     
  "test_begin_rescue_else_ensure_bodies",                                            
  "test_begin_rescue_else_ensure_no_bodies",                                         
  "test_begin_rescue_ensure_no_bodies",                                              
  "test_block_arg__bare",                                                            
  "test_block_args_kwargs",                                                          
  "test_block_args_no_kwargs",                                                       
  "test_block_args_opt1",                                                            
  "test_block_args_opt2_2",                                                          
  "test_block_args_opt3",                                                            
  "test_block_call_defn_call_block_call",                                            
  "test_block_call_dot_op2_brace_block",
  "test_block_call_dot_op2_cmd_args_do_block",
  "test_block_call_operation_colon",
  "test_block_call_operation_dot",
  "test_block_call_paren_call_block_call",
  "test_block_command_operation_colon",
  "test_block_command_operation_dot",
  "test_block_kwarg_lvar",
  "test_block_kwarg_lvar_multiple",
  "test_bug169",
  "test_bug179",
  "test_bug190",
  "test_bug202",
  "test_bug236",
  "test_bug290",
  "test_bug_187",
  "test_bug_215",
  "test_bug_249",
  "test_bug_args__19",
  "test_bug_case_when_regexp",
  "test_bug_comma",
  "test_bug_cond_pct",
  "test_bug_hash_interp_array",
  "test_bug_op_asgn_rescue",
  "test_call_array_block_call",
  "test_call_array_lambda_block_call",
  "test_call_begin_call_block_call",
  "test_call_block_arg_named",
  "test_call_env",
  "test_call_stabby_do_end_with_block",
  "test_call_stabby_with_braces_block",
  /^test_case_in_/,
  "test_class_comments",
  "test_dasgn_icky2",
  "test_defn_arg_forward_args",
  "test_defn_args_forward_args",
  "test_defn_comments",
  "test_defn_forward_args",
  "test_defn_kwarg_env",
  "test_defn_kwarg_lvar",
  "test_defn_no_kwargs",
  "test_defn_oneliner",
  "test_defn_oneliner_rescue",
  "test_defns_reserved",
  "test_defs_as_arg_with_do_block_inside",
  "test_defs_comments",
  "test_defs_oneliner",
  "test_defs_oneliner_eq2",
  "test_defs_oneliner_rescue",
  "test_do_bug",
  "test_dstr_lex_state",
  "test_eq_begin_why_wont_people_use_their_spacebar?",
  "test_evstr_str",
  "test_flip2_env_lvar",
  /^test_heredoc_/,
  "test_i_fucking_hate_line_numbers",
  "test_i_fucking_hate_line_numbers2",
  "test_index_0_opasgn",
  "test_kill_me5",
  "test_lasgn_env",
  "test_lasgn_ivar_env",
  "test_masgn_anon_splat_arg",
  "test_masgn_arg_colon_arg",
  "test_masgn_arg_ident",
  "test_masgn_arg_splat_arg",
  "test_masgn_colon2",
  "test_masgn_colon3",
  "test_masgn_command_call",
  "test_masgn_double_paren",
  "test_masgn_lhs_splat",
  "test_masgn_paren",
  "test_masgn_splat_arg",
  "test_masgn_splat_arg_arg",
  "test_masgn_star",
  "test_masgn_var_star_var",
  "test_messy_op_asgn_lineno",
  "test_mlhs_back_anonsplat",
  "test_mlhs_back_splat",
  "test_mlhs_front_anonsplat",
  "test_mlhs_front_splat",
  "test_mlhs_mid_anonsplat",
  "test_mlhs_mid_splat",
  "test_mlhs_rescue",
  "test_module_comments",
  "test_non_interpolated_word_array_line_breaks",
  "test_op_asgn_command_call",
  "test_op_asgn_dot_ident_command_call",
  "test_op_asgn_index_command_call",
  "test_op_asgn_primary_colon_const_command_call",
  "test_op_asgn_primary_colon_identifier1",
  "test_op_asgn_primary_colon_identifier_command_call",
  "test_op_asgn_val_dot_ident_command_call",
  "test_op_asgn_val_dot_ident_command_calescaped_newline",
  /^test_parse_line_/,
  "test_parse_pattern_058",
  "test_parse_pattern_058_2",
  "test_pctW_lineno",
  "test_pct_w_heredoc_interp_nested",
  "test_pct_Q_backslash_nl",
  "test_qsymbols_interp",
  "test_qw_escape_term",
  "test_read_escape_unicode_curlies",
  "test_read_escape_unicode_h4",
  "test_regexp",
  "test_regexp_escape_extended",
  "test_regexp_unicode_curlies",
  "test_regexp_esc_u",
  "test_regexp_esc_C_slash",
  "test_return_call_assocs",
  "test_rhs_asgn",
  "test_safe_attrasgn",
  "test_safe_attrasgn_constant",
  "test_safe_op_asgn",
  "test_safe_op_asgn2",
  "test_slashy_newlines_within_string",
  "test_stabby_block_iter_call",
  "test_stabby_block_iter_call_no_target_with_arg",
  "test_str_double_double_escaped_newline",
  "test_str_double_escaped_newline",
  "test_str_double_newline",
  "test_str_evstr_escape",
  "test_str_heredoc_interp",
  "test_str_interp_ternary_or_label",
  "test_str_lit_concat_bad_encodings",
  "test_str_newline_hash_line_number",
  "test_str_pct_Q_nested",
  "test_str_pct_nested_nested",
  "test_str_single_double_escaped_newline",
  "test_str_single_escaped_newline",
  "test_super_arg",
  "test_when_splat",
  "test_words_interp",
  "test_wtf",
  "test_wtf_7",
  "test_wtf_8",
  "test_zomg_sometimes_i_hate_this_project",

  # Skipping this as it's meant to raise an error.
  "test_magic_encoding_comment__bad",

  # Skipping this until we can get shadow args on lambda literals working.
  "test_stabby_proc_scope"
]
