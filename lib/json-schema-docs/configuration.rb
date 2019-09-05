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
      pipeline_config: {
        pipeline:
          %i(ExtendedMarkdownFilter
           EmojiFilter
           TableOfContentsFilter
           SyntaxHighlightFilter),
        context: {
          gfm: false,
          unsafe: true, # necessary for layout needs, given that it's all HTML templates
          asset_root: 'https://a248.e.akamai.net/assets.github.com/images/icons'
        }
      },
      renderer: JsonSchemaDocs::Renderer,
      use_default_styles: true,
      base_url: '',

      templates: {
        default: "#{File.dirname(__FILE__)}/layouts/default.html.erb",

        includes: "#{File.dirname(__FILE__)}/layouts/includes",

        links: "#{File.dirname(__FILE__)}/layouts/links.html.erb",
        resource: "#{File.dirname(__FILE__)}/layouts/resource.html.erb",
      },

      landing_pages: {
        index: "#{File.dirname(__FILE__)}/landing_pages/index.md",

        variables: {} # only used for ERB landing pages
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
