# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"

  file_list = FileList["test/**/*_test.rb"]
  file_list << "parser/test/test_parser.rb"
  t.test_files = file_list
end

task default: :test
