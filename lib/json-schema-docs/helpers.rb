# frozen_string_literal: true

require 'commonmarker'

module JsonSchemaDocs
  module Helpers
    SLUGIFY_PRETTY_REGEXP = Regexp.new("[^[:alnum:]._~!$&'()+,;=@]+").freeze

    attr_accessor :templates

    def slugify(str)
      slug = str.gsub(SLUGIFY_PRETTY_REGEXP, '-')
      slug.gsub!(%r!^\-|\-$!i, '')
      slug.downcase
    end

    def include(filename, opts = {})
      template = fetch_include(filename)
      opts = { base_url: @options[:base_url] }.merge(opts)
      template.result(OpenStruct.new(opts.merge(helper_methods)).instance_eval { binding })
    end

    def markdownify(string)
      return '' if string.nil?
      type = @options[:pipeline_config][:context][:unsafe] ? :UNSAFE : :DEFAULT
      ::CommonMarker.render_html(string, type).strip
    end

    def types
      @parsed_schema.keys
    end

    def schemata(name)
      @parsed_schema[name]
    end

    private

    def fetch_include(filename)
      @templates ||= {}

      return @templates[filename] unless @templates[filename].nil?

      contents = File.read(File.join(@options[:templates][:includes], filename))

      @templates[filename] = ERB.new(contents, nil, '-')
    end

    def helper_methods
      return @helper_methods if defined?(@helper_methods)

      @helper_methods = {}

      Helpers.instance_methods.each do |name|
        next if name == :helper_methods
        @helper_methods[name] = method(name)
      end

      @helper_methods
    end
  end
end
