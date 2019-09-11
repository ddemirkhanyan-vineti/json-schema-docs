# frozen_string_literal: true
require 'erb'

module JsonSchemaDocs
  class Generator
    include Helpers

    attr_accessor :parsed_schema

    DYNAMIC_PAGES = %i(links resource)
    STATIC_PAGES = %i(index)

    def initialize(parsed_schema, options)
      @parsed_schema = parsed_schema
      @options = options

      @renderer = @options[:renderer].new(@parsed_schema, @options)

      DYNAMIC_PAGES.each do |sym|
        if !File.exist?(@options[:templates][sym])
          raise IOError, "`#{sym}` template #{@options[:templates][sym]} was not found"
        end
        instance_variable_set("@json_schema_#{sym}_template", ERB.new(File.read(@options[:templates][sym]), nil, '-'))
      end

      STATIC_PAGES.each do |sym|
        if @options[:landing_pages][sym].nil?
          instance_variable_set("@#{sym}_landing_page", nil)
        elsif !File.exist?(@options[:landing_pages][sym])
          raise IOError, "`#{sym}` landing page #{@options[:landing_pages][sym]} was not found"
        end

        landing_page_contents = File.read(@options[:landing_pages][sym])

        instance_variable_set("@json_schema_#{sym}_landing_page", landing_page_contents)
      end
    end

    def generate
      FileUtils.rm_rf(@options[:output_dir]) if @options[:delete_output]

      @parsed_schema.each_pair do |resource, schemata|
        DYNAMIC_PAGES.each do |type|
          layout = instance_variable_get("@json_schema_#{type}_template")
          opts = @options.merge(helper_methods)

          opts[:schemata_resource] = resource
          opts[:schemata] = schemata

          contents = layout.result(OpenStruct.new(opts).instance_eval { binding })
          write_file(type, resource, schemata['title'], contents)
        end
      end

      STATIC_PAGES.each do |name|
        landing_page = instance_variable_get("@json_schema_#{name}_landing_page")

        unless landing_page.nil?
          write_file(:landing_page, name.to_s, nil, landing_page, trim: false)
        end
      end

      if @options[:use_default_styles]
        assets_dir = File.join(File.dirname(__FILE__), 'layouts', 'assets')
        FileUtils.mkdir_p(File.join(@options[:output_dir], 'assets'))

        sass = File.join(assets_dir, 'css', 'screen.scss')
        system `sass --sourcemap=none #{sass}:#{@options[:output_dir]}/assets/style.css`
      end

      true
    end

    private

    def write_file(type, name, title, contents, trim: true)
      if type == :landing_page
        if name == 'index'
          path = @options[:output_dir]
        else
          path = File.join(@options[:output_dir], name)
          FileUtils.mkdir_p(path)
        end
      elsif type == :resource
        path = File.join(@options[:output_dir], 'resources', name.downcase)
      elsif type == :links
        path = File.join(@options[:output_dir], 'resources', name.downcase, 'links')
      end

      FileUtils.mkdir_p(path)

      meta = { type: type, title: title, name: name }
      if has_yaml?(contents)
        # Split data
        frontmatter, contents = split_into_metadata_and_contents(contents)
        meta = frontmatter.merge(meta)
      end

      if trim
        # normalize spacing so that CommonMarker doesn't treat it as `pre`
        contents = contents.gsub(/^\s+$/, '')
        contents = contents.gsub(/^\s{4}/m, '  ')
      end

      filename = File.join(path, 'index.html')
      meta[:filename] = filename
      output = @renderer.render(contents, meta: meta)
      File.write(filename, output) unless output.nil?
    end

    def split_into_metadata_and_contents(contents, parse: true)
      opts = {}
      pieces = yaml_split(contents)
      if pieces.size < 4
        raise RuntimeError.new(
          "The file '#{content_filename}' appears to start with a metadata section (three or five dashes at the top) but it does not seem to be in the correct format.",
        )
      end
      # Parse
      begin
        if parse
          meta = YAML.load(pieces[2]) || {}
        else
          meta = pieces[2]
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        raise "Could not parse YAML for #{name}: #{e.message}"
      end
      [meta, pieces[4]]
    end

    def has_yaml?(contents)
      contents =~ /\A-{3,5}\s*$/
    end

    def yaml_split(contents)
      contents.split(/^(-{5}|-{3})[ \t]*\r?\n?/, 3)
    end
  end
end
