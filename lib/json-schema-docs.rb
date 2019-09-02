# frozen_string_literal: true
require 'json-schema-docs/helpers'
require 'json-schema-docs/configuration'
require 'json-schema-docs/generator'
require 'json-schema-docs/parser'
require 'json-schema-docs/version'

begin
  require 'awesome_print'
  require 'pry'
rescue LoadError; end

module JsonSchemaDocs
  class << self
    def build(options)
      options = JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS.merge(options)

      filename = options[:filename]
      schema = options[:schema]

      if !filename.nil? && !schema.nil?
        raise ArgumentError, 'Pass in `filename` or `schema`, but not both!'
      end

      if filename.nil? && schema.nil?
        raise ArgumentError, 'Pass in either `filename` or `schema`'
      end

      if filename
        unless filename.is_a?(String)
          raise TypeError, "Expected `String`, got `#{filename.class}`"
        end

        unless File.exist?(filename)
          raise ArgumentError, "#{filename} does not exist!"
        end

        schema = File.read(filename)
      else
        if !schema.is_a?(String) && !schema.is_a?(Prmd::Schema)
          raise TypeError, "Expected `String` or `Prmd::Schema`, got `#{schema.class}`"
        end

        schema = schema
      end

      parser = JsonSchemaDocs::Parser.new(schema, options)
      parsed_schema = parser.parse

      generator = JsonSchemaDocs::Generator.new(parsed_schema, options)

      generator.generate
    end
  end
end
