# frozen_string_literal: true
require 'bundler/gem_tasks'
require 'rake/testtask'

require 'rubocop/rake_task'

RuboCop::RakeTask.new(:rubocop)

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.warning = false
  t.test_files = FileList['test/**/*_test.rb']
end

task default: :test

desc 'Generate the documentation'
task :generate_sample do
  require 'pry'
  require 'json-schema-docs'

  options = {}
  options[:delete_output] = true
  options[:filename] = File.join(File.dirname(__FILE__), 'test', 'json-schema-docs', 'fixtures', 'heroku.json')

  JsonSchemaDocs.build(options)
end

desc 'Generate the documentation and run a web server'
task sample: [:generate_sample] do
  require 'webrick'

  puts 'Navigate to http://localhost:3000 to see the sample docs'

  server = WEBrick::HTTPServer.new Port: 3000
  server.mount '/', WEBrick::HTTPServlet::FileHandler, 'output'
  trap('INT') { server.stop }
  server.start
end
