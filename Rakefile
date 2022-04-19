# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"

  # We're going to make a list of our own test files, as well as the parser test
  # from the parser gem which we've included as a submodule.
  file_list = FileList["test/**/*_test.rb"]
  file_list << "parser/test/test_parser.rb"

  t.test_files = file_list
end

task default: :test
