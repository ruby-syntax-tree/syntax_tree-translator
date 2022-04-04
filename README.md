# SyntaxTree::ParserTranslator

This is a proof-of-concept for translating the AST used by [Syntax Tree](https://github.com/ruby-syntax-tree/syntax_tree) into the AST used by [parser](https://github.com/whitequark/parser).

## Getting started

To test it out, edit the content at the bottom of the `run` script under the `__END__` to be any Ruby content. The run `./run`.

If the ASTs don't match, it will tell you the error. If they do match, then it will benchmark the two generation paths.
