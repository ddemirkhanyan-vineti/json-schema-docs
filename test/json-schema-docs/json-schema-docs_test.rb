# frozen_string_literal: true
require 'test_helper'

class JsonSchemaDocsTest < Minitest::Test
  def test_that_it_requires_a_file_or_string
    assert_raises ArgumentError do
      JsonSchemaDocs.build({})
    end
  end

  def test_it_demands_string_argument
    assert_raises TypeError do
      JsonSchemaDocs.build(filename: 43)
    end

    assert_raises TypeError do
      JsonSchemaDocs.build(schema: 43)
    end
  end

  def test_it_needs_a_file_that_exists
    assert_raises ArgumentError do
      JsonSchemaDocs.build(filename: 'not/a/real/file')
    end
  end

  def test_it_needs_one_or_the_other
    assert_raises ArgumentError do
      JsonSchemaDocs.build(filename: 'http://json-schema.org/schema.json', schema: File.join(fixtures_dir, 'heroku.json'))
    end

    assert_raises ArgumentError do
      JsonSchemaDocs.build
    end
  end
end
