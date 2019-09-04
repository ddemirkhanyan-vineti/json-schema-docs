# frozen_string_literal: true
require 'erb'

module JsonSchemaDocs
  class Generator
    include Helpers

    attr_accessor :parsed_schema

    def initialize(parsed_schema, options)
      @parsed_schema = parsed_schema
      @options = options

      %i(endpoint object).each do |sym|
        if !File.exist?(@options[:templates][sym])
          raise IOError, "`#{sym}` template #{@options[:templates][sym]} was not found"
        end
        instance_variable_set("@json_schema_#{sym}_template", ERB.new(File.read(@options[:templates][sym]), nil, '-'))
      end
    end

    def generate
      FileUtils.rm_rf(@options[:output_dir]) if @options[:delete_output]

      @parsed_schema.each_pair do |resource, schemata|
        %i(endpoint object).each do |type|
          contents = render(type, resource, schemata)
          write_file(type, resource, contents)

          contents = render(type, resource, schemata)
          write_file(type, resource, contents)
        end
      end
    end

    private

    def render(type, resource, schemata)
      layout = instance_variable_get("@json_schema_#{type}_template")
      opts = @options.merge(helper_methods)

      opts[:schemata_resource] = resource
      opts[:schemata] = schemata
      layout.result(OpenStruct.new(opts).instance_eval { binding })
    end

    def write_file(type, name, contents, trim: true)
      if type == :object
        path = File.join(@options[:output_dir], 'objects', name.downcase)
        FileUtils.mkdir_p(path)
      elsif type == :endpoint
        path = File.join(@options[:output_dir], 'objects', name.downcase, 'endpoints')
        FileUtils.mkdir_p(path)
      end

      if trim
        # normalize spacing so that CommonMarker doesn't treat it as `pre`
        contents = contents.gsub(/^\s+$/, '')
        contents = contents.gsub(/^\s{4}/m, '  ')
      end

      filename = File.join(path, 'index.md')
      File.write(filename, contents) unless contents.nil?
    end
  end
end
