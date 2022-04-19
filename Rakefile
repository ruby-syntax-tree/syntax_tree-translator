# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"

  # This is the list of tests from our translator gem itself.
  file_list = FileList["test/**/*_test.rb"]

  # This is a big test file from the parser gem that tests its functionality.
  file_list << "suites/parser/test/test_parser.rb"

  # This is a big test file from the ruby_parser gem that tests its
  # functionality.
  file_list << "suites/ruby_parser/test/test_ruby_parser.rb"

  t.test_files = file_list
end

task default: :test
