# frozen_string_literal: true
module JsonSchemaDocs
  module Configuration
    JSON_SCHEMA_DOCS_DEFAULTS = {
      # initialize
      filename: nil,
      schema: nil,

      # Generating
      delete_output: false,
      output_dir: './output/',

      templates: {
        endpoint: "#{File.dirname(__FILE__)}/layouts/endpoint.md.erb",
        object: "#{File.dirname(__FILE__)}/layouts/object.md.erb",

        includes: "#{File.dirname(__FILE__)}/layouts/includes",
      },

      prmd: {
        http_header: {},
        content_type: 'application/json',
        doc: {
          url_style: 'default'
        }
      }
    }.freeze
  end
end
