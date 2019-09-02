# frozen_string_literal: true
require 'test_helper'

class GeneratorTest < Minitest::Test
  def setup
    schema = File.read(File.join(fixtures_dir, 'schema.json'))
    @parser = JsonSchemaDocs::Parser.new(schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    @results = @parser.parse

    @output_dir = File.join(fixtures_dir, 'output')
  end

  def deep_copy(hash)
    Marshal.load(Marshal.dump(hash))
  end

  def test_that_it_requires_templates
    options = deep_copy(JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    options[:templates][:endpoint] = 'BOGUS'

    assert_raises IOError do
      JsonSchemaDocs::Generator.new(@results, options)
    end
  end

  def test_that_it_works
    options = deep_copy(JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    options[:output_dir] = @output_dir
    options[:delete_output] = true

    generator = JsonSchemaDocs::Generator.new(@results, options)
    generator.generate

    post_object_file = File.join(@output_dir, 'objects', 'post', 'index.md')
    assert File.exist? post_object_file
    assert_match %r{# <a class="header-link" name="resource-post">Post</a>}, File.read(post_object_file)

    user_object_file = File.join(@output_dir, 'objects', 'user', 'index.md')
    assert File.exist? user_object_file
    assert_match %r{# <a class="header-link" name="resource-user">User</a>}, File.read(user_object_file)

    assert File.exist? File.join(@output_dir, 'objects', 'post', 'endpoints', 'index.md')
    assert File.exist? File.join(@output_dir, 'objects', 'user', 'endpoints', 'index.md')
  end
end
