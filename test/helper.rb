# frozen_string_literal: true

$:.unshift(File.expand_path("../lib", __dir__))

require "parser/current"
require "syntax_tree/translator"

require "minitest/autorun"
