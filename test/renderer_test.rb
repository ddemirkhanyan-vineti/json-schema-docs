# frozen_string_literal: true
require 'test_helper'

class RendererTest < Minitest::Test

  def setup
    schema = File.read(File.join(fixtures_dir, 'simple.json'))
    @parsed_schema = JsonSchemaDocs::Parser.new(schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS).parse
    @renderer = JsonSchemaDocs::Renderer.new(@parsed_schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS)
  end

  def test_that_rendering_works
    contents = @renderer.render('R2D2', meta: { name: 'R2D2' })

    assert_match %r{<title>R2D2</title>}, contents
  end

  def test_that_html_conversion_works
    contents = @renderer.to_html('**R2D2**')

    assert_equal '<p><strong>R2D2</strong></p>', contents
  end

  def test_that_unsafe_html_is_not_blocked_by_default
    contents = @renderer.to_html('<strong>Oh hello</strong>')

    assert_equal '<p><strong>Oh hello</strong></p>', contents
  end

  def test_that_unsafe_html_is_blocked_when_asked
    renderer = JsonSchemaDocs::Renderer.new(@parsed_schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS.merge({
      pipeline_config: {
        pipeline:
          %i(ExtendedMarkdownFilter
             EmojiFilter
             TableOfContentsFilter),
        context: {
          gfm: false,
          unsafe: false,
          asset_root: 'https://a248.e.akamai.net/assets.github.com/images/icons'
        }
      }
    }))
    contents = renderer.to_html('<strong>Oh</strong> **hello**')

    assert_equal '<p><!-- raw HTML omitted -->Oh<!-- raw HTML omitted --> <strong>hello</strong></p>', contents
  end

  def test_that_filename_accessible_to_filters
    renderer = JsonSchemaDocs::Renderer.new(@parsed_schema, JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS.merge({
      pipeline_config: {
        pipeline:
          %i(ExtendedMarkdownFilter
             EmojiFilter
             TableOfContentsFilter
             AddFilenameFilter),
        context: {
          gfm: false,
          unsafe: true,
          asset_root: 'https://a248.e.akamai.net/assets.github.com/images/icons'
        }
      }
    }))
    contents = renderer.render('<span id="fill-me"></span>', meta: { type: 'Droid', name: 'R2D2', filename: '/this/is/the/filename' })
    assert_match %r{<span id="fill-me">/this/is/the/filename</span>}, contents
  end
end

class AddFilenameFilter < HTML::Pipeline::Filter
  def call
    doc.search('span[@id="fill-me"]').each do |span|
      span.inner_html=(context[:filename])
    end
    doc
  end

  def validate
    needs :filename
  end
end
