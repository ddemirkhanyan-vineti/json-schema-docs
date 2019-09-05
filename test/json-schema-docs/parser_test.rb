# frozen_string_literal: true
require 'test_helper'

class ParserTest < Minitest::Test
  def setup
    @schema = File.read(File.join(fixtures_dir, 'simple.json'))
  end

  def test_it_parses_string
    assert @schema.class, String

    parser = JsonSchemaDocs::Parser.new(@schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    results = parser.parse

    assert_equal ['post', 'user'], results.keys
    assert_equal 5, results['post']['links'].length
    assert_equal 'POST', results['post']['links'].first['method']
  end

  def test_it_parses_prmd_schema
    data = Prmd::MultiLoader::Json.load_data(@schema)

    schema = Prmd::Schema.new(data)

    assert schema.class, Prmd::Schema

    parser = JsonSchemaDocs::Parser.new(schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    results = parser.parse

    assert_equal ['post', 'user'], results.keys
    assert_equal 5, results['post']['links'].length
    assert_equal 'POST', results['post']['links'].first['method']
  end
end
