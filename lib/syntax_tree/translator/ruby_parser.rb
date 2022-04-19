# frozen_string_literal: true

module SyntaxTree
  module Translator
    class RubyParser < Visitor
      attr_reader :stack

      def initialize
        @stack = []
      end

      def visit(node)
        stack << node
        result = super
        stack.pop
        result
      end

      # Visit an ARef node.
      def visit_aref(node)
        case node
        in { index: Args[parts: [part]] }
          s(:call, visit(node.collection), :[], visit(part))
        in { index: nil }
          s(:call, visit(node.collection), :[])
        end
      end

      # Visit an ARefField node.
      def visit_aref_field(node)
        case node
        in { index: Args[parts: [part]] }
          s(:attrasgn, visit(node.collection), :[]=, visit(part))
        in { index: nil }
          s(:attrasgn, visit(node.collection), :[]=)
        end
      end

      # Visit an Alias node.
      def visit_alias(node)
        s(:alias, visit(node.left), visit(node.right))
      end

      # Visit an ArgBlock node.
      def visit_arg_block(node)
        children = []
        children << visit(node.value) if node.value
        s(:block_pass, *children)
      end

      # Visit an ArgParen node.
      def visit_arg_paren(node)
        raise
      end

      # Visit an ArgStar node.
      def visit_arg_star(node)
        case node
        in { value: nil | Ident }
          :"*#{visit(node.value)}"
        else
          s(:splat, visit(node.value))
        end
      end

      # Visit an Args node.
      def visit_args(node)
        s(:args, *visit_all(node.parts))
      end

      # Visit an ArgsForward node.
      def visit_args_forward(node)
        raise
      end

      # Visit an ArrayLiteral node.
      def visit_array(node)
        case node
        in { contents: nil }
          s(:array)
        in { contents: }
          s(:array, *visit(contents)[1..])
        end
      end

      # Visit an AryPtn node.
      def visit_aryptn(node)
        children = [visit(node.constant)] + visit_all(node.requireds)
        children << visit(node.rest) if node.rest
        children += visit_all(node.posts)
        s(:array_pat, *children)
      end

      # Visit an Assign node.
      def visit_assign(node)
        s(*visit(node.target), visit(node.value))
      end

      # Visit an Assoc node.
      def visit_assoc(node)
        [visit(node.key), visit(node.value)]
      end

      # Visit an AssocSplat node.
      def visit_assoc_splat(node)
        [s(:kwsplat, visit(node.value))]
      end

      # Visit a Backref node.
      def visit_backref(node)
        node.value.to_sym
      end

      # Visit a Backtick node.
      def visit_backtick(node)
        raise
      end

      # Visit a BareAssocHash node.
      def visit_bare_assoc_hash(node)
        s(:hash, *visit_all(node.assocs).flatten(1))
      end

      # Visit a BEGINBlock node.
      def visit_BEGIN(node)
        s(:iter, s(:preexe), 0, visit(node.statements))
      end

      # Visit a Begin node.
      def visit_begin(node)
        raise
      end

      # Visit a Binary node.
      def visit_binary(node)
        case node
        in { operator: :and }
          s(:and, visit(node.left), visit(node.right))
        in { operator: :"!~" }
          s(:not, s(:call, visit(node.left), :=~, visit(node.right)))
        else
          s(:call, visit(node.left), node.operator, visit(node.right))
        end
      end

      # Visit a BlockArg node.
      def visit_blockarg(node)
        :"&#{visit(node.name)}"
      end

      # Visit a BlockVar node.
      def visit_block_var(node)
        case node
        in { locals: [] }
          s(*visit(node.params))
        else
          s(*visit(node.params), s(:shadow, *node.locals.map { |local| visit(local) }))
        end
      end

      # Visit a BodyStmt node.
      def visit_bodystmt(node)
        visit(node.statements)
      end

      # Visit a BraceBlock node.
      def visit_brace_block(node)
        raise
      end

      # Visit a Break node.
      def visit_break(node)
        s(:break, *visit(node.arguments)[1..])
      end

      # Visit a Call node.
      def visit_call(node)
        case node
        in { message: :call, arguments: ArgParen[arguments: nil] }
          s(call_type(node.operator), visit(node.receiver), :call)
        in { message: :call, arguments: ArgParen[arguments: { parts: }] }
          s(call_type(node.operator), visit(node.receiver), :call, *visit_all(parts))
        in { arguments: nil | ArgParen[arguments: nil] }
          s(call_type(node.operator), visit(node.receiver), node.message.value.to_sym)
        in { arguments: Args[parts:] }
          s(call_type(node.operator), visit(node.receiver), node.message.value.to_sym, *visit_all(parts))
        in { arguments: ArgParen[arguments: { parts: }] }
          s(call_type(node.operator), visit(node.receiver), node.message.value.to_sym, *visit_all(parts))
        end
      end

      # Visit a Case node.
      def visit_case(node)
        clauses = [node.consequent]
        clauses << clauses.last.consequent while clauses.last && !(clauses.last in Else)
        s(:case, visit(node.value), *visit_all(clauses))
      end

      # Visit a CHAR node.
      def visit_CHAR(node)
        s(:str, node.value[1..])
      end

      # Visit a ClassDeclaration node.
      def visit_class(node)
        s(:class, visit(node.constant), visit(node.superclass), visit(node.bodystmt))
      end

      # Visit a Comma node.
      def visit_comma(node)
        raise
      end

      # Visit a Command node.
      def visit_command(node)
        s(:call, nil, node.message.value.to_sym, *visit_all(node.arguments.parts))
      end

      # Visit a CommandCall node.
      def visit_command_call(node)
        arguments =
          case node
          in { arguments: nil }
            # do nothing
          in { arguments: Args[parts:] }
            visit_all(parts)
          in { arguments: ArgParen[arguments: { parts: }] }
            visit_all(parts)
          end

        s(call_type(node.operator), visit(node.receiver), visit(node.message), *arguments)
      end

      # Visit a Comment node.
      def visit_comment(node)
        raise
      end

      # Visit a Const node.
      def visit_const(node)
        s(:const, node.value.to_sym)
      end

      # Visit a ConstPathField node.
      def visit_const_path_field(node)
        s(:colon2, visit(node.parent), node.constant.value.to_sym)
      end

      # Visit a ConstPathRef node.
      def visit_const_path_ref(node)
        raise
      end

      # Visit a ConstRef node.
      def visit_const_ref(node)
        node.constant.value.to_sym
      end

      # Visit a CVar node.
      def visit_cvar(node)
        s(:cvar, node.value.to_sym)
      end

      # Visit a Def node.
      def visit_def(node)
        args = (node.params in Params) ? node.params : node.params.contents
        s(:defn, node.name.value.to_sym, visit(args), visit(node.bodystmt))
      end

      # Visit a DefEndless node.
      def visit_def_endless(node)
        children = []
        children << visit(node.target) if node.target

        args = (node.paren in Params) ? node.paren : node.paren.contents
        children += [node.name.value.to_sym, visit(args), visit(node.statement)]

        s(node.target ? :defs : :defn, *children)
      end

      # Visit a Defined node.
      def visit_defined(node)
        s(:defined, visit(node.value))
      end

      # Visit a Defs node.
      def visit_defs(node)
        args = (node.params in Params) ? node.params : node.params.contents
        s(:defs, visit(node.target), visit(node.name), visit(args), visit(node.bodystmt))
      end

      # Visit a DoBlock node.
      def visit_do_block(node)
        raise
      end

      # Visit a Dot2 node.
      def visit_dot2(node)
        s(:dot2, visit(node.left), visit(node.right))
      end

      # Visit a Dot3 node.
      def visit_dot3(node)
        s(:dot3, visit(node.left), visit(node.right))
      end

      # Visit a DynaSymbol node.
      def visit_dyna_symbol(node)
        case node
        in { parts: [] }
          s(:lit, :"")
        in { parts: [TStringContent => part] }
          s(:lit, part.value.to_sym)
        in { parts: [StringEmbExpr => part, *parts] }
          s(:dsym, "", visit(part), *visit_all(parts))
        else
          s(:dsym, *visit_all(node.parts))
        end
      end

      # Visit an ENDBlock node.
      def visit_END(node)
        s(:iter, s(:postexe), 0, visit(node.statements))
      end

      # Visit an Else node.
      def visit_else(node)
        visit(node.statements)
      end

      # Visit an Elsif node.
      def visit_elsif(node)
        statements = node.statements.empty? ? nil : visit(node.statements)
        s(:if, visit(node.predicate), statements, visit(node.consequent))
      end

      # Visit an EmbDoc node.
      def visit_embdoc(node)
        raise
      end

      # Visit an EmbExprBeg node.
      def visit_embexpr_beg(node)
        raise
      end

      # Visit an EmbExprEnd node.
      def visit_embexpr_end(node)
        raise
      end

      # Visit an EmbVar node.
      def visit_embvar(node)
        raise
      end

      # Visit an Ensure node.
      def visit_ensure(node)
        raise
      end

      # Visit an ExcessedComma node.
      def visit_excessed_comma(node)
        raise
      end

      # Visit a FCall node.
      def visit_fcall(node)
        case node
        in { arguments: Args[parts: []] | ArgParen[arguments: nil] }
          s(:call, nil, node.value.value.to_sym)
        in { arguments: ArgParen[arguments: { parts: }] }
          s(:call, nil, node.value.value.to_sym, *visit_all(parts))
        in { arguments: ArgParen[arguments: ArgsForward] }
          s(:call, nil, node.value.value.to_sym, s(:forwarded_args))
        end
      end

      # Visit a Field node.
      def visit_field(node)
        s(:attrasgn, visit(node.parent), :"#{node.name.value}=")
      end

      # Visit a FloatLiteral node.
      def visit_float(node)
        s(:lit, node.value.to_f)
      end

      # Visit a FndPtn node.
      def visit_fndptn(node)
        raise
      end

      # Visit a For node.
      def visit_for(node)
        raise
      end

      # Visit a GVar node.
      def visit_gvar(node)
        node.value.to_sym
      end

      # Visit a HashLiteral node.
      def visit_hash(node)
        s(:hash, *visit_all(node.assocs).flatten(1))
      end

      # Visit a Heredoc node.
      def visit_heredoc(node)
        raise
      end

      # Visit a HeredocBeg node.
      def visit_heredoc_beg(node)
        raise
      end

      # Visit a HshPtn node.
      def visit_hshptn(node)
        children = [
          visit(node.constant),
          *node.keywords.flat_map { |(keyword, value)| [visit(keyword), visit(value)] }
        ]

        children << visit(node.keyword_rest) if node.keyword_rest
        s(:hash_pat, *children)
      end

      # Visit an Ident node.
      def visit_ident(node)
        node.value.to_sym
      end

      # Visit an If node.
      def visit_if(node)
        statements = node.statements.empty? ? nil : visit(node.statements)
        s(:if, visit(node.predicate), statements, visit(node.consequent))
      end

      # Visit an IfMod node.
      def visit_if_mod(node)
        s(:if, visit(node.predicate), visit(node.statement), nil)
      end

      # Visit an IfOp node.
      def visit_if_op(node)
        s(:if, visit(node.predicate), visit(node.truthy), visit(node.falsy))
      end

      # Visit an Imaginary node.
      def visit_imaginary(node)
        s(:lit, eval(node.value))
      end

      # Visit an In node.
      def visit_in(node)
        s(:in, visit(node.pattern), visit(node.statements))
      end

      # Visit an Int node.
      def visit_int(node)
        s(:lit, node.value.to_i)
      end

      # Visit an IVar node.
      def visit_ivar(node)
        s(:ivar, node.value.to_sym)
      end

      # Visit a Kw node.
      def visit_kw(node)
        s(node.value.to_sym)
      end

      # Visit a KwRestParam node.
      def visit_kwrest_param(node)
        :"**#{visit(node.name)}"
      end

      # Visit a Label node.
      def visit_label(node)
        value = node.value.chomp(":").to_sym
        (stack[-2] in Params) ? value : s(:lit, value)
      end

      # Visit a LabelEnd node.
      def visit_label_end(node)
        raise
      end

      # Visit a Lambda node.
      def visit_lambda(node)
        children = [s(:lambda)]

        case node
        in { params: Paren[contents: Params => params] } if params.empty?
          children << s(:args)
        in { params: Params => params } if params.empty?
          children << 0
        else
          children << visit(node.params)
        end

        children << visit(node.statements) unless node.statements.empty?

        s(:iter, *children)
      end

      # Visit a LBrace node.
      def visit_lbrace(node)
        raise
      end

      # Visit a LBracket node.
      def visit_lbracket(node)
        raise
      end

      # Visit a LParen node.
      def visit_lparen(node)
        raise
      end

      # Visit a MAssign node.
      def visit_massign(node)
        s(:masgn, s(:array, visit(node.target)), s(:to_ary, visit(node.value)))
      end

      # Visit a MethodAddBlock node.
      def visit_method_add_block(node)
        statements =
          if node.block in BraceBlock
            node.block.statements
          else
            node.block.bodystmt
          end

        block = statements.empty? ? nil : visit(statements)

        if node.call in Break | Next | Return | Yield
          type, *children = visit(node.call)
          s(type, s(:iter, *children, visit(node.block.block_var), *block))
        else
          s(:iter, visit(node.call), visit(node.block.block_var), *block)
        end
      end

      # Visit a MLHS node.
      def visit_mlhs(node)
        s(:masgn, *visit_all(node.parts))
      end

      # Visit a MLHSParen node.
      def visit_mlhs_paren(node)
        visit(node.contents)
      end

      # Visit a ModuleDeclaration node.
      def visit_module(node)
        raise
      end

      # Visit a MRHS node.
      def visit_mrhs(node)
        s(:svalue, s(:array, *visit_all(node.parts)))
      end

      # Visit a Next node.
      def visit_next(node)
        s(:next, *visit(node.arguments)[1..])
      end

      # Visit a Not node.
      def visit_not(node)
        s(:call, visit(node.statement), :"!")
      end

      # Visit an Op node.
      def visit_op(node)
        node.value.to_sym
      end

      # Visit an OpAssign node.
      def visit_opassign(node)
        case node.operator
        in { value: "||=" }
          s(:op_asgn_or, visit(node.target), visit(node.value))
        in { value: "&&=" }
          s(:op_asgn_and, visit(node.target), visit(node.value))
        else
          s(:op_asgn, visit(node.target), node.operator.value.chomp("=").to_sym, visit(node.value))
        end
      end

      # Visit a Params node.
      def visit_params(node)
        s(
          :args,
          *node.requireds.map { |required| visit(required) },
          *node.optionals.map { |(name, value)| s(:lasgn, visit(name), visit(value)) },
          *visit(node.rest),
          *node.posts.map { |post| visit(post) },
          *node.keywords.map do |(name, value)|
            children = [visit(name)]
            children << visit(value) if value
            s(:kwarg, *children)
          end,
          *visit(node.keyword_rest),
          *visit(node.block)
        )
      end

      # Visit a Paren node.
      def visit_paren(node)
        visit(node.contents)
      end

      # Visit a Period node.
      def visit_period(node)
        raise
      end

      # Visit a PinnedBegin node.
      def visit_pinned_begin(node)
        raise
      end

      # Visit a PinnedVarRef node.
      def visit_pinned_var_ref(node)
        raise
      end

      # Visit a Program node.
      def visit_program(node)
        visit(node.statements)
      end

      # Visit a QSymbols node.
      def visit_qsymbols(node)
        s(
          :array,
          *node.elements.map { |element| s(:lit, element.value.to_sym) }
        )
      end

      # Visit a QSymbolsBeg node.
      def visit_qsymbols_beg(node)
        raise
      end

      # Visit a QWords node.
      def visit_qwords(node)
        s(:array, *visit_all(node.elements))
      end

      # Visit a QWordsBeg node.
      def visit_qwords_beg(node)
        raise
      end

      # Visit a RAssign node.
      def visit_rassign(node)
        s(:case, visit(node.value), s(:in, visit(node.pattern), nil), nil)
      end

      # Visit a RationalLiteral node.
      def visit_rational(node)
        s(:lit, node.value.to_r)
      end

      # Visit a RBrace node.
      def visit_rbrace(node)
        raise
      end

      # Visit a RBracket node.
      def visit_rbracket(node)
        raise
      end

      # Visit a Redo node.
      def visit_redo(node)
        s(:redo)
      end

      # Visit a RegexpBeg node.
      def visit_regexp_beg(node)
        raise
      end

      # Visit a RegexpContent node.
      def visit_regexp_content(node)
        raise
      end

      # Visit a RegexpEnd node.
      def visit_regexp_end(node)
        raise
      end

      # Visit a RegexpLiteral node.
      def visit_regexp_literal(node)
        raise
      end

      # Visit a Rescue node.
      def visit_rescue(node)
        raise
      end

      # Visit a RescueEx node.
      def visit_rescue_ex(node)
        raise
      end

      # Visit a RescueMod node.
      def visit_rescue_mod(node)
        s(:rescue, visit(node.statement), s(:resbody, s(:array), visit(node.value)))
      end

      # Visit a RestParam node.
      def visit_rest_param(node)
        :"*#{visit(node.name)}"
      end

      # Visit a Retry node.
      def visit_retry(node)
        s(:retry)
      end

      # Visit a Return node.
      def visit_return(node)
        s(:return, *visit(node.arguments)[1..])
      end

      # Visit a Return0 node.
      def visit_return0(node)
        s(:return)
      end

      # Visit a RParen node.
      def visit_rparen(node)
        raise
      end

      # Visit a SClass node.
      def visit_sclass(node)
        raise
      end

      # Visit a Statements node.
      def visit_statements(node)
        children = node.body.reject { |child| child in Comment | EmbDoc | EndContent | VoidStmt }

        case children
        in []
          s(:nil)
        in [child]
          visit(child)
        else
          s(:block, *visit_all(children))
        end
      end

      # Visit a StringConcat node.
      def visit_string_concat(node)
        raise
      end

      # Visit a StringContent node.
      def visit_string_content(node)
        raise
      end

      # Visit a StringDVar node.
      def visit_string_dvar(node)
        raise
      end

      # Visit a StringEmbExpr node.
      def visit_string_embexpr(node)
        s(:evstr, visit(node.statements))
      end

      # Visit a StringLiteral node.
      def visit_string_literal(node)
        children = [+""]

        node.parts.each_with_index do |part, index|
          if children.last in String
            case part
            in StringEmbExpr[statements: { body: [StringLiteral[parts: [TStringContent => tstring]]] }]
              children.last << visit(tstring)
            in TStringContent
              children.last << visit(part)
            else
              children << visit(part)
            end
          else
            children << visit(part)
          end
        end

        case children
        in [String => child]
          s(:str, child)
        else
          s(:dstr, *children)
        end
      end

      # Visit a Super node.
      def visit_super(node)
        raise
      end

      # Visit a SymBeg node.
      def visit_symbeg(node)
        raise
      end

      # Visit a SymbolContent node.
      def visit_symbol_content(node)
        raise
      end

      # Visit a SymbolLiteral node.
      def visit_symbol_literal(node)
        s(:lit, node.value.value.to_sym)
      end

      # Visit a Symbols node.
      def visit_symbols(node)
        s(:array, *visit_all(node.elements))
      end

      # Visit a SymbolsBeg node.
      def visit_symbols_beg(node)
        raise
      end

      # Visit a TLambda node.
      def visit_tlambda(node)
        raise
      end

      # Visit a TLamBeg node.
      def visit_tlambeg(node)
        raise
      end

      # Visit a TopConstField node.
      def visit_top_const_field(node)
        s(:colon3, node.constant.value.to_sym)
      end

      # Visit a TopConstRef node.
      def visit_top_const_ref(node)
        s(:colon3, node.constant.value.to_sym)
      end

      # Visit a TStringBeg node.
      def visit_tstring_beg(node)
        raise
      end

      # Visit a TStringContent node.
      def visit_tstring_content(node)
        node.value
      end

      # Visit a TStringEnd node.
      def visit_tstring_end(node)
        raise
      end

      # Visit an Unary node.
      def visit_unary(node)
        case node
        in { operator: "+" }
          s(:call, visit(node.statement), :+@)
        in { statement: FloatLiteral[value:], operator: "-" }
          s(:lit, -value.to_f)
        in { statement: Int[value:], operator: "-" }
          s(:lit, -value.to_i)
        in { operator: "-" }
          s(:call, visit(node.statement), :-@)
        else
          s(:call, visit(node.statement), node.operator.to_sym)
        end
      end

      # Visit an Undef node.
      def visit_undef(node)
        raise
      end

      # Visit an Unless node.
      def visit_unless(node)
        raise
      end

      # Visit an UnlessMod node.
      def visit_unless_mod(node)
        s(:unless, visit(node.predicate), visit(node.statement), nil)
      end

      # Visit an Until node.
      def visit_until(node)
        s(:until, visit(node.predicate), visit(node.statements), true)
      end

      # Visit an UntilMod node.
      def visit_until_mod(node)
        s(:until, visit(node.predicate), visit(node.statement), true)
      end

      # Visit a VarAlias node.
      def visit_var_alias(node)
        s(:valias, visit(node.left), visit(node.right))
      end

      # Visit a VarField node.
      def visit_var_field(node)
        case node.value
        in Const[value:] then s(:casgn, nil, value.to_sym)
        in CVar[value:] then s(:cvasgn, value.to_sym)
        in GVar[value:] then s(:gvasgn, value.to_sym)
        in Ident[value:] then s(:lasgn, value.to_sym)
        in IVar[value:] then s(:ivasgn, value.to_sym)
        in VarRef[value:] then s(:lasgn, value.to_sym)
        in :nil then s(:kwrest, :"**nil")
        in nil then :*
        end
      end

      # Visit a VarRef node.
      def visit_var_ref(node)
        visit(node.value)
      end

      # Visit a VCall node.
      def visit_vcall(node)
        s(:call, nil, node.value.value.to_sym)
      end

      # Visit a VoidStmt node.
      def visit_void_stmt(node)
        raise
      end

      # Visit a When node.
      def visit_when(node)
        cases = s(:array, *visit_all(node.arguments.parts))
        statements = node.statements.empty? ? nil : visit(node.statements)
        s(:when, cases, statements)
      end

      # Visit a While node.
      def visit_while(node)
        s(:while, visit(node.predicate), visit(node.statements), true)
      end

      # Visit a WhileMod node.
      def visit_while_mod(node)
        s(:while, visit(node.predicate), visit(node.statement), true)
      end

      # Visit a Word node.
      def visit_word(node)
        case stack[-2]
        in Symbols
          case node
          in { parts: [TStringContent => part] }
            s(:lit, part.value.to_sym)
          in { parts: [StringEmbExpr => part, *parts] }
            s(:dsym, "", visit(part), *visit_all(parts))
          else
            s(:dsym, *visit_all(parts))
          end
        in Words
          case node
          in { parts: [TStringContent => part] }
            s(:str, visit(part))
          in { parts: [StringEmbExpr => part, *parts] }
            s(:dstr, "", visit(part), *visit_all(parts))
          else
            s(:dstr, *visit_all(parts))
          end
        end
      end

      # Visit a Words node.
      def visit_words(node)
        s(:array, *visit_all(node.elements))
      end

      # Visit a WordsBeg node.
      def visit_words_beg(node)
        raise
      end

      # Visit a XString node.
      def visit_xstring(node)
        raise
      end

      # Visit a XStringLiteral node.
      def visit_xstring_literal(node)
        case node
        in { parts: [StringEmbExpr => part, *parts] }
          s(:dxstr, "", visit(part), *visit_all(parts))
        else
          s(:dxstr, *visit_all(node.parts))
        end
      end

      # Visit a Yield node.
      def visit_yield(node)
        case node
        in { arguments: Args[parts:] }
          s(:yield, *visit_all(parts))
        in { arguments: Paren[contents: Args[parts:]] }
          s(:yield, *visit_all(parts))
        end
      end

      # Visit a Yield0 node.
      def visit_yield0(node)
        s(:yield)
      end

      # Visit a ZSuper node.
      def visit_zsuper(node)
        s(:zsuper)
      end

      # Visit an EndContent node.
      def visit___end__(node)
        raise
      end

      private

      def call_type(operator)
        (operator in Op[value: "&."]) ? :safe_call : :call
      end

      def s(*args)
        Sexp.new(*args)
      end
    end
  end
end
