# SyntaxTree::Translator

This is a proof-of-concept for translating the AST used by [Syntax Tree](https://github.com/ruby-syntax-tree/syntax_tree) into the AST used by either the [parser](https://github.com/whitequark/parser) gem or the [rubocop-ast](https://github.com/rubocop/rubocop-ast) gem.

## Getting started

To test it out, run the tests with `bundle exec rake`. That will run the `parser` gem's parser tests against the translating visitor. As of the latest commit, it results in:

```
442 runs, 752 assertions, 0 failures, 0 errors, 3 skips
```
