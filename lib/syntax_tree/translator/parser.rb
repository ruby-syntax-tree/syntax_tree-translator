# frozen_string_literal: true

module SyntaxTree
  module Translator
    class Parser < BasicVisitor
      attr_reader :buffer, :stack

      def initialize(buffer)
        @buffer = buffer
        @stack = []
      end

      def visit(node)
        stack << node
        result = super
        stack.pop
        result
      end

      def visit_alias(node)
        s(:alias, [visit(node.left), visit(node.right)])
      end

      def visit_aref_field(node)
        if ::Parser::Builders::Default.emit_index
          case node
          in { index: Args[parts:] }
            s(:indexasgn, [visit(node.collection), *visit_all(parts)])
          in { index: nil }
            s(:indexasgn, [visit(node.collection), nil])
          end
        else
          case node
          in { index: Args[parts:] }
            s(:send, [visit(node.collection), :[]=, *visit_all(parts)])
          in { index: nil }
            s(:send, [visit(node.collection), :[]=, nil])
          end
        end
      end

      def visit_aref(node)
        if ::Parser::Builders::Default.emit_index
          case node
          in { index: Args[parts:] }
            s(:index, [visit(node.collection), *visit_all(parts)])
          in { index: nil }
            s(:index, [visit(node.collection)])
          end
        else
          case node
          in { index: Args[parts:] }
            s(:send, [visit(node.collection), :[], *visit_all(parts)])
          in { index: nil }
            s(:send, [visit(node.collection), :[], nil])
          end
        end
      end

      def visit_arg_block(node)
        s(:block_pass, [visit(node.value)])
      end

      def visit_arg_star(node)
        if stack[-3] in MLHSParen[contents: MLHS]
          case node
          in { value: nil }
            s(:restarg)
          in { value: VarField[value: { value: }]}
            s(:restarg, [value.to_sym])
          in { value: Ident[value:] }
            s(:restarg, [value.to_sym])
          end
        else
          case node
          in { value: nil }
            s(:splat)
          else
            s(:splat, [visit(node.value)])
          end
        end
      end

      def visit_args_forward(node)
        s(:forwarded_args)
      end

      def visit_array(node)
        case node
        in { contents: nil }
          s(:array)
        in { contents: Args[parts:] }
          s(:array, visit_all(parts))
        end
      end

      def visit_aryptn(node)
        type = :array_pattern
        children = visit_all(node.requireds)

        case node.rest
        in VarField[value: nil, location: { start_char:, end_char: ^(start_char) }] if node.posts.empty?
          # Here we have an implicit rest, as in [foo,]. parser has a specific
          # type for these patterns.
          type = :array_pattern_with_tail
        in VarField[value: nil]
          children << s(:match_rest)
        in VarField
          children << s(:match_rest, [visit(node.rest)])
        else
        end

        inner = s(type, children + visit_all(node.posts))
        node.constant ? s(:const_pattern, [visit(node.constant), inner]) : inner
      end

      def visit_assign(node)
        target = visit(node.target)
        s(target.type, target.children + [visit(node.value)])
      end

      def visit_assoc(node)
        case node
        in { key:, value: nil } if key.value.start_with?(/[a-z]/)
          s(:pair, [visit(key), s(:send, [nil, key.value.chomp(":").to_sym])])
        in { key:, value: nil } if key.value.start_with?(/[A-Z]/)
          s(:pair, [visit(key), s(:const, [nil, key.value.chomp(":").to_sym])])
        in { key:, value: }
          s(:pair, [visit(key), visit(value)])
        end
      end

      def visit_assoc_splat(node)
        s(:kwsplat, [visit(node.value)])
      end

      def visit_backref(node)
        if node.value.match?(/^\$\d+$/)
          s(:nth_ref, [node.value[1..-1].to_i])
        else
          s(:back_ref, [node.value.to_sym])
        end
      end

      def visit_bare_assoc_hash(node)
        type =
          if ::Parser::Builders::Default.emit_kwargs && !(stack[-2] in ArrayLiteral)
            :kwargs
          else
            :hash
          end

        s(type, visit_all(node.assocs))
      end

      def visit_BEGIN(node)
        s(:preexe, [visit(node.statements)])
      end

      def visit_begin(node)
        if node.bodystmt.empty?
          s(:kwbegin)
        elsif node.bodystmt in { statements:, rescue_clause: nil, ensure_clause: nil, else_clause: nil }
          visited = visit(statements)
          s(:kwbegin, visited.type == :begin ? visited.children : [visited])
        else
          s(:kwbegin, [visit(node.bodystmt)])
        end
      end

      def visit_binary(node)
        case node
        in { operator: :| }
          current = -2
          current -= 1 while (stack[current] in Binary[operator: :|])

          if stack[current] in In
            s(:match_alt, [visit(node.left), visit(node.right)])
          else
            s(:send, [visit(node.left), node.operator, visit(node.right)])
          end
        in { operator: :"=>" }
          s(:match_as, [visit(node.left), visit(node.right)])
        in { operator: :"&&" | :and }
          s(:and, [visit(node.left), visit(node.right)])
        in { operator: :"||" | :or }
          s(:or, [visit(node.left), visit(node.right)])
        in { left: RegexpLiteral[parts: [TStringContent]], operator: :=~ }
          s(:match_with_lvasgn, [visit(node.left), visit(node.right)])
        else
          s(:send, [visit(node.left), node.operator, visit(node.right)])
        end
      end

      def visit_blockarg(node)
        case node
        in { name: nil }
          s(:blockarg, [nil])
        else
          s(:blockarg, [node.name.value.to_sym])
        end
      end

      def visit_block_var(node)
        shadowargs = node.locals.map { |local| s(:shadowarg, [local.value.to_sym]) }

        case node
        in { params: { requireds: [(Ident | MLHSParen) => required], optionals: [], rest: nil, posts: [], keywords: [], keyword_rest: nil, block: nil } } if ::Parser::Builders::Default.emit_procarg0
          procarg0 =
            if ::Parser::Builders::Default.emit_arg_inside_procarg0 && required in Ident
              s(:procarg0, [s(:arg, [required.value.to_sym])])
            else
              s(:procarg0, visit(required).children)
            end

          s(:args, [procarg0] + shadowargs)
        else
          s(:args, visit(node.params).children + shadowargs)
        end
      end

      def visit_bodystmt(node)
        inner = visit(node.statements)

        if node.rescue_clause
          children = [inner] + visit(node.rescue_clause).children

          if node.else_clause
            children.pop
            children << visit(node.else_clause)
          end

          inner = s(:rescue, children)
        end

        if node.ensure_clause
          inner = s(:ensure, [inner] + visit(node.ensure_clause).children)
        end

        inner
      end

      def visit_break(node)
        s(:break, visit_all(node.arguments.parts))
      end

      def visit_call(node)
        type = send_type(node.operator)

        case node
        in { receiver: nil, arguments: Args[parts: []] | ArgParen[arguments: nil] }
          s(:send, [nil, node.message.value.to_sym])
        in { receiver: nil, arguments: ArgParen[arguments: { parts: }] }
          s(:send, [nil, node.message.value.to_sym, *visit_all(parts)])
        in { receiver: nil, arguments: ArgParen[arguments: ArgsForward] }
          s(:send, [nil, node.message.value.to_sym, s(:forwarded_args)])
        in { message: :call, arguments: ArgParen[arguments: nil] }
          s(type, [visit(node.receiver), :call])
        in { message: :call, arguments: ArgParen[arguments: { parts: }] }
          s(type, [visit(node.receiver), :call, *visit_all(parts)])
        in { arguments: nil | ArgParen[arguments: nil] }
          s(type, [visit(node.receiver), node.message.value.to_sym])
        in { arguments: Args[parts:] }
          s(type, [visit(node.receiver), node.message.value.to_sym, *visit_all(parts)])
        in { arguments: ArgParen[arguments: { parts: }] }
          s(type, [visit(node.receiver), node.message.value.to_sym, *visit_all(parts)])
        end
      end

      def visit_case(node)
        clauses = [node.consequent]
        clauses << clauses.last.consequent while clauses.last && !(clauses.last in Else)

        type = (node.consequent in In) ? :case_match : :case
        s(type, [visit(node.value)] + clauses.map { |clause| visit(clause) })
      end

      def visit_CHAR(node)
        s(:str, [node.value[1..-1]])
      end

      def visit_class(node)
        s(:class, [visit(node.constant), visit(node.superclass), visit(node.bodystmt)])
      end

      def visit_command(node)
        call = s(:send, [nil, node.message.value.to_sym, *visit_all(node.arguments.parts)])

        if node.block
          type, arguments = block_children(node.block)
          s(type, [call, arguments, visit(node.block.bodystmt)])
        else
          call
        end
      end

      def visit_command_call(node)
        children = [visit(node.receiver), node.message.value.to_sym]

        case node.arguments
        in nil
          # do nothing
        in Args[parts:]
          children += visit_all(parts)
        in ArgParen[arguments: { parts: }]
          children += visit_all(parts)
        end

        call = s(send_type(node.operator), children)

        if node.block
          type, arguments = block_children(node.block)
          s(type, [call, arguments, visit(node.block.bodystmt)])
        else
          call
        end
      end

      def visit_const(node)
        s(:const, [nil, node.value.to_sym])
      end

      def visit_const_path_field(node)
        if node in { parent: VarRef[value: Kw[value: "self"]] => parent, constant: Ident[value:] }
          s(:send, [visit(parent), :"#{value}="])
        else
          s(:casgn, [visit(node.parent), node.constant.value.to_sym])
        end
      end

      def visit_const_path_ref(node)
        s(:const, [visit(node.parent), node.constant.value.to_sym])
      end

      def visit_const_ref(node)
        s(:const, [nil, node.constant.value.to_sym])
      end

      def visit_cvar(node)
        s(:cvar, [node.value.to_sym])
      end

      def visit_def(node)
        args = (node.params in Params) ? node.params : node.params.contents

        if node.target
          target = node.target.is_a?(Paren) ? node.target.contents : node.target
          s(:defs, [visit(target), node.name.value.to_sym, visit(args), visit(node.bodystmt)])
        else
          s(:def, [node.name.value.to_sym, visit(args), visit(node.bodystmt)])
        end
      end

      def visit_defined(node)
        s(:defined?, [visit(node.value)])
      end

      def visit_dyna_symbol(node)
        case node
        in { parts: [TStringContent[value:]] }
          s(:sym, ["\"#{value}\"".undump.to_sym])
        else
          s(:dsym, visit_all(node.parts))
        end
      end

      def visit_else(node)
        if node.statements.empty? && (stack[-2] in Case)
          s(:empty_else)
        else
          visit(node.statements)
        end
      end

      def visit_elsif(node)
        s(:if, [visit(node.predicate), visit(node.statements), visit(node.consequent)])
      end

      def visit_END(node)
        s(:postexe, [visit(node.statements)])
      end

      def visit_ensure(node)
        s(:ensure, [visit(node.statements)])
      end

      def visit_field(node)
        if stack[-2] in Assign | MLHS
          s(send_type(node.operator), [visit(node.parent), :"#{node.name.value}="])
        else
          s(send_type(node.operator), [visit(node.parent), node.name.value.to_sym])
        end
      end

      def visit_float(node)
        s(:float, [node.value.to_f])
      end

      def visit_fndptn(node)
        children = [
          s(:match_rest, (node.left in VarField[value: nil]) ? [] : [visit(node.left)]),
          *visit_all(node.values),
          s(:match_rest, (node.right in VarField[value: nil]) ? [] : [visit(node.right)])
        ]

        inner = s(:find_pattern, children)
        node.constant ? s(:const_pattern, [visit(node.constant), inner]) : inner
      end

      def visit_for(node)
        s(:for, [visit(node.index), visit(node.collection), visit(node.statements)])
      end

      def visit_gvar(node)
        s(:gvar, [node.value.to_sym])
      end

      def visit_hash(node)
        s(:hash, visit_all(node.assocs))
      end

      class HeredocSegments
        attr_reader :node, :segments

        def initialize(node)
          @node = node
          @segments = []
        end

        def <<(segment)
          if segment.type == :str && segments.last && segments.last.type == :str && !segments.last.children.first.end_with?("\n")
            segments.last.children.first << segment.children.first
          else
            segments << segment
          end
        end

        HeredocLine = Struct.new(:value, :segments)

        def trim!
          return unless node.beginning.value[2] == "~"
          lines = [HeredocLine.new(+"", [])]

          segments.each do |segment|
            lines.last.segments << segment

            if segment.type == :str
              lines.last.value << segment.children.first

              if lines.last.value.end_with?("\n")
                lines << HeredocLine.new(+"", [])
              end
            end
          end

          lines.pop if lines.last.value.empty?
          return if lines.empty?

          segments.clear
          lines.each do |line|
            remaining = node.dedent

            line.segments.each do |segment|
              if segment.type == :str
                if remaining > 0
                  whitespace = segment.children.first[/^\s{0,#{remaining}}/]
                  segment.children.first.sub!(/^#{whitespace}/, "")
                  remaining -= whitespace.length
                end

                if node.beginning.value[3] != "'" && segments.any? && segments.last.type == :str && segments.last.children.first.end_with?("\\\n")
                  segments.last.children.first.gsub!(/\\\n\z/, "")
                  segments.last.children.first.concat(segment.children.first)
                elsif segment.children.first.length > 0
                  segments << segment
                end
              else
                segments << segment
              end
            end
          end
        end
      end

      def visit_heredoc(node)
        heredoc_segments = HeredocSegments.new(node)

        node.parts.each do |part|
          if (part in TStringContent[value:]) && value.count("\n") > 1
            part.value.split("\n").each do |line|
              heredoc_segments << s(:str, ["#{line}\n"])
            end
          else
            heredoc_segments << visit(part)
          end
        end

        heredoc_segments.trim!

        if node.beginning.value.match?(/`\w+`\z/)
          s(:xstr, heredoc_segments.segments)
        elsif heredoc_segments.segments.length > 1
          s(:dstr, heredoc_segments.segments)
        elsif heredoc_segments.segments.empty?
          s(:dstr)
        else
          heredoc_segments.segments.first
        end
      end

      def visit_hshptn(node)
        children =
          node.keywords.map do |(keyword, value)|
            next s(:pair, [visit(keyword), visit(value)]) if value

            case keyword
            in Label
              s(:match_var, [keyword.value.chomp(":").to_sym])
            in StringContent[parts: [TStringContent[value:]]]
              s(:match_var, [value.to_sym])
            end
          end

        case node.keyword_rest
        in VarField[value: nil]
          children << s(:match_rest)
        in VarField[value: :nil]
          children << s(:match_nil_pattern)
        in VarField
          children << s(:match_rest, [visit(node.keyword_rest)])
        else
        end

        inner = s(:hash_pattern, children)
        node.constant ? s(:const_pattern, [visit(node.constant), inner]) : inner
      end

      def visit_ident(node)
        s(:lvar, [node.value.to_sym])
      end

      # Visit an IfNode node.
      def visit_if(node)
        predicate =
          if node.predicate.is_a?(RangeNode)
            type = node.predicate.operator.value == ".." ? :iflipflop : :eflipflop
            s(type, visit(node.predicate).children)
          else
            visit(node.predicate)
          end

        s(:if, [predicate, visit(node.statements), visit(node.consequent)])
      end

      def visit_if_op(node)
        s(:if, [visit(node.predicate), visit(node.truthy), visit(node.falsy)])
      end

      def visit_imaginary(node)
        # We have to do an eval here in order to get the value in case it's
        # something like 42ri. to_c will not give the right value in that case.
        # Maybe there's an API for this but I can't find it.
        s(:complex, [eval(node.value)])
      end

      def visit_in(node)
        case node
        in { pattern: IfNode[predicate:, statements:], statements: in_statements }
          s(:in_pattern, [visit(statements), s(:if_guard, [visit(predicate)]), visit(in_statements)])
        in { pattern: UnlessNode[predicate:, statements:], statements: in_statements }
          s(:in_pattern, [visit(statements), s(:unless_guard, [visit(predicate)]), visit(in_statements)])
        else
          s(:in_pattern, [visit(node.pattern), nil, visit(node.statements)])
        end
      end

      def visit_int(node)
        s(:int, [node.value.to_i])
      end

      def visit_ivar(node)
        s(:ivar, [node.value.to_sym])
      end

      def visit_kw(node)
        case node.value
        in "__FILE__"
          s(:str, [buffer.name])
        in "__LINE__"
          s(:int, [node.location.start_line + buffer.first_line - 1])
        in "__ENCODING__" unless ::Parser::Builders::Default.emit_encoding
          s(:const, [s(:const, [nil, :Encoding]), :UTF_8])
        else
          s(node.value.to_sym)
        end
      end

      def visit_kwrest_param(node)
        case node
        in { name: nil }
          s(:kwrestarg)
        else
          s(:kwrestarg, [node.name.value.to_sym])
        end
      end

      def visit_label(node)
        s(:sym, [node.value.chomp(":").to_sym])
      end

      def visit_lambda(node)
        args = (node.params in LambdaVar) ? node.params : node.params.contents

        arguments = visit(args)
        child =
          if ::Parser::Builders::Default.emit_lambda
            s(:lambda)
          else
            s(:send, [nil, :lambda])
          end

        type = :block
        if args.empty? && (maximum = num_block_type(node.statements))
          type = :numblock
          arguments = maximum
        end

        s(type, [child, arguments, visit(node.statements)])
      end

      def visit_lambda_var(node)
        shadowargs = node.locals.map { |local| s(:shadowarg, [local.value.to_sym]) }

        s(:args, visit(node.params).children + shadowargs)
      end

      def visit_massign(node)
        s(:masgn, [visit(node.target), visit(node.value)])
      end

      def visit_method_add_block(node)
        type, arguments = block_children(node.block)

        if node.call in Break | Next | ReturnNode
          call = visit(node.call)
          s(call.type, [s(type, [*call.children, arguments, visit(node.block.bodystmt)])])
        else
          s(type, [visit(node.call), arguments, visit(node.block.bodystmt)])
        end
      end

      def visit_mlhs(node)
        s(:mlhs, node.parts.map { |part| (part in Ident[value:]) ? s(:arg, [value.to_sym]) : visit(part) })
      end

      def visit_mlhs_paren(node)
        visit(node.contents)
      end

      def visit_module(node)
        s(:module, [visit(node.constant), visit(node.bodystmt)])
      end

      def visit_mrhs(node)
        s(:array, visit_all(node.parts))
      end

      def visit_next(node)
        s(:next, visit_all(node.arguments.parts))
      end

      def visit_not(node)
        case node
        in { statement: nil }
          s(:send, [s(:begin), :"!"])
        else
          s(:send, [visit(node.statement), :"!"])
        end
      end

      def visit_opassign(node)
        case node.operator
        in { value: "||=" }
          s(:or_asgn, [visit(node.target), visit(node.value)])
        in { value: "&&=" }
          s(:and_asgn, [visit(node.target), visit(node.value)])
        else
          s(:op_asgn, [visit(node.target), node.operator.value.chomp("=").to_sym, visit(node.value)])
        end
      end

      def visit_params(node)
        children = []

        children +=
          node.requireds.map do |required|
            case required
            in MLHSParen
              visit(required)
            else
              s(:arg, [required.value.to_sym])
            end
          end

        children += node.optionals.map { |(name, value)| s(:optarg, [name.value.to_sym, visit(value)]) }
        children << visit(node.rest) if node.rest && !(node.rest in ExcessedComma)
        children += node.posts.map { |post| s(:arg, [post.value.to_sym]) }
        children +=
          node.keywords.map do |(name, value)|
            key = name.value.chomp(":").to_sym
            value ? s(:kwoptarg, [key, visit(value)]) : s(:kwarg, [key])
          end

        case node.keyword_rest
        in nil | ArgsForward
          # do nothing
        in :nil
          children << s(:kwnilarg)
        else
          children << visit(node.keyword_rest)
        end

        children << visit(node.block) if node.block
        
        if (node.keyword_rest in ArgsForward)
          if children.empty? && !::Parser::Builders::Default.emit_forward_arg
            return s(:forward_args)
          end

          children.insert(node.requireds.length + node.optionals.length + node.keywords.length, s(:forward_arg))
        end

        s(:args, children)
      end

      def visit_paren(node)
        if node in { contents: nil | Statements[body: [VoidStmt]] }
          s(:begin)
        elsif stack[-2].is_a?(DefNode) && stack[-2].target.nil? && stack[-2].target == node
          visit(node.contents)
        else
          visited = visit(node.contents)
          visited.type == :begin ? visited : s(:begin, [visited])
        end
      end

      def visit_pinned_begin(node)
        s(:pin, [s(:begin, [visit(node.statement)])])
      end

      def visit_pinned_var_ref(node)
        s(:pin, [visit(node.value)])
      end

      def visit_program(node)
        visit(node.statements)
      end

      def visit_qsymbols(node)
        s(:array, node.elements.map { |element| s(:sym, [element.value.to_sym]) })
      end

      def visit_qwords(node)
        s(:array, visit_all(node.elements))
      end

      # Visit a RangeNode node.
      def visit_range(node)
        type = node.operator.value == ".." ? :irange : :erange
        s(type, [visit(node.left), visit(node.right)])
      end

      def visit_rassign(node)
        type = (node.operator in Op[value: "=>"]) ? :match_pattern : :match_pattern_p
        s(type, [visit(node.value), visit(node.pattern)])
      end

      def visit_rational(node)
        s(:rational, [node.value.to_r])
      end

      def visit_redo(node)
        s(:redo)
      end

      def visit_regexp_literal(node)
        children = visit_all(node.parts)
        children << s(:regopt, node.ending.scan(/[a-z]/).sort.map(&:to_sym))
        regexp = s(:regexp, children)

        if stack[-2] in IfNode[predicate: ^(node)] | UnlessNode[predicate: ^(node)]
          s(:match_current_line, [regexp])
        elsif stack[-3] in IfNode[predicate: Unary[statement: ^(node), operator: "!"]] | UnlessNode[predicate: Unary[statement: ^(node), operator: "!"]]
          s(:match_current_line, [regexp])
        elsif stack[-4] in Program[statements: { body: [*, Unary[statement: ^(node), operator: "!"]] }]
          s(:match_current_line, [regexp])
        else
          regexp
        end
      end

      def visit_rescue(node)
        exceptions =
          case node.exception
          in nil | { exceptions: nil }
            nil
          in { exceptions: VarRef => part }
            s(:array, [visit(part)])
          in { exceptions: MRHS[parts:] }
            s(:array, visit_all(parts))
          else
            s(:array, [visit(node.exception.exceptions)])
          end

        resbody =
          case node.exception
          in nil
            s(:resbody, [nil, nil, visit(node.statements)])
          in { variable: nil }
            s(:resbody, [exceptions, nil, visit(node.statements)])
          in { variable: VarField => variable }
            s(:resbody, [exceptions, visit(variable), visit(node.statements)])
          end

        children = [resbody]
        if node.consequent
          children += visit(node.consequent).children
        else
          children << nil
        end

        s(:rescue, children)
      end

      def visit_rescue_mod(node)
        s(:rescue, [visit(node.statement), s(:resbody, [nil, nil, visit(node.value)]), nil])
      end

      def visit_rest_param(node)
        s(:restarg, node.name ? [node.name.value.to_sym] : [])
      end

      def visit_retry(node)
        s(:retry)
      end

      def visit_return(node)
        s(:return, node.arguments ? visit_all(node.arguments.parts) : [])
      end

      def visit_return0(node)
        s(:return)
      end

      def visit_sclass(node)
        s(:sclass, [visit(node.target), visit(node.bodystmt)])
      end

      def visit_statements(node)
        children = node.body.reject { |child| child in Comment | EmbDoc | EndContent | VoidStmt }

        case children
        in []
          nil
        in [statement]
          visit(statement)
        else
          s(:begin, visit_all(children))
        end
      end

      def visit_string_concat(node)
        s(:dstr, [visit(node.left), visit(node.right)])
      end

      def visit_string_content(node)
        # Can get here if you're inside a hash pattern, e.g., in "a": 1
        s(:sym, [node.parts.first.value.to_sym])
      end

      def visit_string_dvar(node)
        visit(node.variable)
      end

      def visit_string_embexpr(node)
        child = visit(node.statements)
        s(:begin, child ? [child] : [])
      end

      def visit_string_literal(node)
        case node
        in { parts: [] }
          s(:str, [""])
        in { parts: [TStringContent => part] }
          visit(part)
        else
          s(:dstr, visit_all(node.parts))
        end
      end

      def visit_super(node)
        case node.arguments
        in ArgParen[arguments: nil]
          s(:super)
        in ArgParen[arguments: ArgsForward => arguments]
          s(:super, [visit(arguments)])
        in ArgParen[arguments: { parts: }]
          s(:super, visit_all(parts))
        in Args[parts:]
          s(:super, visit_all(parts))
        end
      end

      def visit_symbol_literal(node)
        s(:sym, [node.value.value.to_sym])
      end

      def visit_symbols(node)
        children =
          node.elements.map do |element|
            if element.parts.length > 1 || !(element.parts.first in TStringContent)
              s(:dsym, visit_all(element.parts))
            else
              s(:sym, [element.parts.first.value.to_sym])
            end
          end

        s(:array, children)
      end

      def visit_top_const_field(node)
        s(:casgn, [s(:cbase), node.constant.value.to_sym])
      end

      def visit_top_const_ref(node)
        s(:const, [s(:cbase), node.constant.value.to_sym])
      end

      def visit_tstring_content(node)
        value = node.value.gsub(/([^[:ascii:]])/) { $1.dump[1...-1] }
        s(:str, ["\"#{value}\"".undump])
      end

      def visit_unary(node)
        case node
        in { statement: Paren[contents: Statements[body: [RangeNode => contents]]], operator: "!" }
          type = contents.operator.value == ".." ? :iflipflop : :eflipflop
          s(:send, [s(:begin, [s(type, visit(contents).children)]), :"!"])
        in { statement: Int[value:], operator: "+" }
          s(:int, [value.to_i])
        in { statement: Int[value:], operator: "-" }
          s(:int, [-value.to_i])
        in { statement: FloatLiteral[value:], operator: "+" }
          s(:float, [value.to_f])
        in { statement: FloatLiteral[value:], operator: "-" }
          s(:float, [-value.to_f])
        in { statement:, operator: "+" }
          s(:send, [visit(statement), :"+@"])
        in { statement:, operator: "-" }
          s(:send, [visit(statement), :"-@"])
        else
          s(:send, [visit(node.statement), node.operator.to_sym])
        end
      end

      def visit_undef(node)
        s(:undef, visit_all(node.symbols))
      end

      def visit_unless(node)
        s(:if, [visit(node.predicate), visit(node.consequent), visit(node.statements)])
      end

      def visit_until(node)
        type =
          if node.modifier? && (node.statements in Statements[body: [Begin]])
            :until_post
          else
            :until
          end

        s(type, [visit(node.predicate), visit(node.statements)])
      end

      def visit_var_field(node)
        if [stack[-3], stack[-2]].any? { |parent| parent in AryPtn | Binary[operator: :"=>"] | FndPtn | HshPtn | In | RAssign }
          return s(:match_var, [node.value.value.to_sym])
        end

        case node.value
        in Const[value:] then s(:casgn, [nil, value.to_sym])
        in CVar[value:] then s(:cvasgn, [value.to_sym])
        in GVar[value:] then s(:gvasgn, [value.to_sym])
        in Ident[value:] then s(:lvasgn, [value.to_sym])
        in IVar[value:] then s(:ivasgn, [value.to_sym])
        in VarRef[value:] then s(:lvasgn, [value.to_sym])
        in nil then s(:match_rest)
        end
      end

      def visit_var_ref(node)
        visit(node.value)
      end

      def visit_vcall(node)
        range = ::Parser::Source::Range.new(buffer, node.location.start_char, node.location.end_char)
        location = ::Parser::Source::Map::Send.new(nil, range, nil, nil, range)

        s(:send, [nil, node.value.value.to_sym], location: location)
      end

      def visit_when(node)
        s(:when, visit_all(node.arguments.parts) + [visit(node.statements)])
      end

      def visit_while(node)
        type =
          if node.modifier? && (node.statements in Statements[body: [Begin]])
            :while_post
          else
            :while
          end

        s(type, [visit(node.predicate), visit(node.statements)])
      end

      def visit_word(node)
        case node
        in { parts: [TStringContent => part] }
          visit(part)
        else
          s(:dstr, visit_all(node.parts))
        end
      end

      def visit_words(node)
        s(:array, visit_all(node.elements))
      end

      def visit_xstring_literal(node)
        s(:xstr, visit_all(node.parts))
      end

      def visit_yield(node)
        case node.arguments
        in nil
          s(:yield)
        in Args[parts:]
          s(:yield, visit_all(parts))
        in Paren[contents: Args[parts:]]
          s(:yield, visit_all(parts))
        end
      end

      def visit_zsuper(node)
        s(:zsuper)
      end

      private

      def block_children(node)
        arguments =
          if node.block_var
            visit(node.block_var)
          else
            s(:args)
          end

        type = :block
        if !node.block_var && (maximum = num_block_type(node.bodystmt))
          type = :numblock
          arguments = maximum
        end

        [type, arguments]
      end

      # We need to find if we should transform this block into a numblock
      # since there could be new numbered variables like _1.
      def num_block_type(statements)
        variables = []
        queue = [statements]

        while child_node = queue.shift
          if (child_node in VarRef[value: Ident[value:]]) && (value =~ /^_(\d+)$/)
            variables << $1.to_i
          end

          queue += child_node.child_nodes.compact
        end

        variables.max
      end

      def s(type, children = [], opts = {})
        ::Parser::AST::Node.new(type, children, opts)
      end

      def send_type(operator)
        (operator in Op[value: "&."]) ? :csend : :send
      end
    end
  end
end
