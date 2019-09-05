# frozen_string_literal: true
require 'test_helper'

class GeneratorTest < Minitest::Test
  class CustomRenderer
    def initialize(_, _)
    end

    def render(contents, meta: {})
      to_html(contents)
    end

    def to_html(contents)
      return '' if contents.nil?
      contents.sub(%r{<code class="stability-type">production</code>}i, 'OH SO SAFE')
    end
  end

  def setup
    schema = File.read(File.join(fixtures_dir, 'heroku.json'))
    @parser = JsonSchemaDocs::Parser.new(schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    @results = @parser.parse

    schema = File.read(File.join(fixtures_dir, 'simple.json'))
    @simple_parser = JsonSchemaDocs::Parser.new(schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    @simple_results = @simple_parser.parse

    @output_dir = File.join(fixtures_dir, 'output')
  end

  def deep_copy(hash)
    Marshal.load(Marshal.dump(hash))
  end

  def test_that_it_requires_templates
    options = deep_copy(JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    options[:templates][:resource] = 'BOGUS'

    assert_raises IOError do
      JsonSchemaDocs::Generator.new(@results, options)
    end
  end

  def test_that_it_works
    options = deep_copy(JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    options[:output_dir] = @output_dir
    options[:delete_output] = true

    generator = JsonSchemaDocs::Generator.new(@simple_results, options)
    generator.generate

    post_object_file = File.join(@output_dir, 'resources', 'post', 'index.html')
    assert File.exist? post_object_file
    assert_match %r{<a name="resource-post">Post</a>}, File.read(post_object_file)

    user_object_file = File.join(@output_dir, 'resources', 'user', 'index.html')
    assert File.exist? user_object_file
    assert_match %r{<a name="resource-user">User</a>}, File.read(user_object_file)

    assert File.exist? File.join(@output_dir, 'resources', 'post', 'links', 'index.html')
    assert File.exist? File.join(@output_dir, 'resources', 'user', 'links', 'index.html')
  end

  def test_that_turning_off_styles_works
    options = deep_copy(JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    options[:output_dir] = @output_dir
    options[:delete_output] = true
    options[:use_default_styles] = false

    generator = JsonSchemaDocs::Generator.new(@results, options)
    generator.generate

    refute File.exist? File.join(@output_dir, 'assets', 'style.css')
  end

  def test_that_setting_base_url_works
    options = deep_copy(JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    options[:output_dir] = @output_dir
    options[:delete_output] = true
    options[:base_url] = 'wowzers'

    generator = JsonSchemaDocs::Generator.new(@results, options)
    generator.generate

    contents = File.read File.join(@output_dir, 'index.html')
    assert_match %r{link rel="stylesheet" href="wowzers/assets/style.css"}, contents

    contents = File.read File.join(@output_dir, 'resources', 'account-feature', 'index.html')
    assert_match %r{href="wowzers/resources/account-feature/"}, contents
  end

  def test_that_custom_renderer_can_be_used
    options = deep_copy(JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    options[:output_dir] = @output_dir

    options[:renderer] = CustomRenderer

    generator = JsonSchemaDocs::Generator.new(@results, options)
    generator.generate

    contents = File.read(File.join(@output_dir, 'resources', 'account', 'index.html'))

    assert_match /OH SO SAFE/, contents
  end
end
