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
    assert_equal 204, results['post']['links'][1]['code']
  end

  def test_it_generates_response_header_using_code_or_rel
    data = Prmd::MultiLoader::Json.load_data(@schema)

    schema = Prmd::Schema.new(data)

    assert schema.class, Prmd::Schema

    parser = JsonSchemaDocs::Parser.new(schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    results = parser.parse

    link_with_rel_create = results['post']['links'][0]
    link_with_rel_self   = results['post']['links'][2]
    link_with_rel_update = results['post']['links'][4]
    link_with_code_204   = results['post']['links'][1]
    link_with_response_head = results['user']['links'][0]

    assert_match /201 Created/, link_with_rel_create["response"][:header]
    assert_match /200 OK/, link_with_rel_self["response"][:header]
    assert_match /200 OK/, link_with_rel_update["response"][:header]
    assert_match /204 No Content/, link_with_code_204["response"][:header]
    assert_match /202 Accepted/, link_with_response_head["response"][:header]
  end

  def test_it_generates_response_example
    data = Prmd::MultiLoader::Json.load_data(@schema)

    schema = Prmd::Schema.new(data)

    assert schema.class, Prmd::Schema

    parser = JsonSchemaDocs::Parser.new(schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
    results = parser.parse

    link_with_given_example_body = results['post']['links'][4]
    actual = JSON.parse(link_with_given_example_body["response"][:example])
    assert_kind_of Hash, actual
    assert_equal "msg", actual.keys.first

    link_with_target_schema = results['post']['links'][2]
    actual = JSON.parse(link_with_target_schema["response"][:example])
    assert_kind_of Hash, actual
    assert_equal %w(created_at id updated_at), actual.keys

    link_with_rel_instances = results['post']['links'][3]
    actual = JSON.parse(link_with_rel_instances["response"][:example])
    assert_kind_of Array, actual
    item = actual.first
    assert_kind_of Hash, item
    assert_equal %w(created_at id updated_at), item.keys

    link_with_code_204   = results['post']['links'][1]
    assert_nil link_with_code_204["response"][:example]
  end
end
