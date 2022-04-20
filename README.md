# SyntaxTree::Translator

[![Build Status](https://github.com/ruby-syntax-tree/syntax_tree-translator/actions/workflows/main.yml/badge.svg)](https://github.com/ruby-syntax-tree/syntax_tree-translator/actions/workflows/main.yml)
[![Gem Version](https://img.shields.io/gem/v/syntax_tree-translator.svg)](https://rubygems.org/gems/syntax_tree-translator)

Translate [Syntax Tree](https://github.com/ruby-syntax-tree/syntax_tree) syntax trees into other Ruby parser syntax trees.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "syntax_tree-translator"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install syntax_tree-translator

## Usage

First, you need to get the source code that you'd like to translate into a syntax tree. Then you need to parse it using Syntax Tree's parse method, as in:

```ruby
source = ARGF.read
program = SyntaxTree.parse(source)
```

From there, you now have a `SyntaxTree::Program` node representing the top of your syntax tree. You can translate that into another format by using one of the provided visitors. Each is detailed below.

### parser

To translate into the [whitequark/parser](https://github.com/whitequark/parser) gem's syntax tree, instantiate a new source buffer, pass that along with the filename and line number into a new visitor, and call visit.

```ruby
buffer = Parser::Source::Buffer.new("(string)")
buffer.source = source

visitor = SyntaxTree::Translator::Parser.new(buffer, "(string)", 1)
node = visitor.visit(program)
```

### rubocop-ast

To translate into the [rubocop/rubocop-ast](https://github.com/rubocop/rubocop-ast) gem's syntax tree (the one used internally by rubocop), you do pretty much the exact same thing as `parser`, except that it generates more specific node types with helper methods.

```ruby
buffer = Parser::Source::Buffer.new("(string)")
buffer.source = source

visitor = SyntaxTree::Translator::RuboCop.new(buffer, "(string)", 1)
node = visitor.visit(program)
```

### ruby_parser

To translate into the [seattlerb/ruby_parser](https://github.com/seattlerb/ruby_parser) gem's syntax tree you instantiate a new visitor and pass it the program instance.

```ruby
visitor = SyntaxTree::Translator::RubyParser.new
node = visitor.visit(program)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby-syntax-tree/syntax_tree-translator.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
