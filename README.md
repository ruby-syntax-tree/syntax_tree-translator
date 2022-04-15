# SyntaxTree::ParserTranslator

This is a proof-of-concept for translating the AST used by [Syntax Tree](https://github.com/ruby-syntax-tree/syntax_tree) into the AST used by [parser](https://github.com/whitequark/parser).

## Getting started

To test it out, run the tests with `bundle exec rake`. That will run the `parser` gem's parser tests against the translating visitor. As of the latest commit, it results in:

```
442 runs, 575 assertions, 94 failures, 8 errors, 0 skips
```
