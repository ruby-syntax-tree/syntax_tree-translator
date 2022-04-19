# frozen_string_literal: true

module SyntaxTree
  module Translator
    class RuboCop < Parser
      private

      def s(type, children = [], opts = {})
        ::RuboCop::AST::Builder::NODE_MAP.fetch(type, ::RuboCop::AST::Node).new(type, children, opts)
      end
    end
  end
end
