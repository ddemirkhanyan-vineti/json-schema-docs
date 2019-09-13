# frozen_string_literal: true
require 'prmd'
require 'neatjson'

module JsonSchemaDocs
  class Parser
    include Helpers

    attr_reader :processed_schema

    def initialize(schema, options)
      @options = options

      if schema.is_a?(Prmd::Schema)
        @schema = schema
      else
        # FIXME: Multiloader has issues: https://github.com/interagent/prmd/issues/279
        # for now just always assume a JSON file
        data = Prmd::MultiLoader::Json.load_data(schema)

        @schema = Prmd::Schema.new(data)
      end

      @processed_schema = {}
    end

    def parse
      @schema['properties'].each_key do |key|
        resource, property = key, @schema['properties'][key]
        begin
          _, schemata = @schema.dereference(property)

          # establish condensed object description
          if schemata['properties'] && !schemata['properties'].empty?
            schemata['property_refs'] = []
            refs = extract_schemata_refs(@schema, schemata['properties']).map { |v| v && v.split('/') }
            extract_attributes(@schema, schemata['properties']).each_with_index do |(key, type, description, example), i|
              property_ref = { type: type, description: description, example: example}
              if refs[i] && refs[i][1] == 'definitions' && refs[i][2] != resource
                property_ref[:name] = '[%s](#%s)' % [key, 'resource-' + refs[i][2]]
              else
                property_ref[:name] = key
              end
              schemata['property_refs'].push(property_ref)
              schemata['example'] = pretty_json(@schema.schemata_example(resource))
            end
          end

          schemata['links'] ||= []

          # establish full link description
          schemata['links'].each do |link, datum|
            link_path = build_link_path(@schema, link)
            response_example = link['response_example']

            if link.has_key?('schema') && link['schema'].has_key?('properties')
              required, optional = Prmd::Link.new(link).required_and_optional_parameters

              unless required.empty?
                link_schema_required_properties = extract_attributes(@schema, required).map do |(name, type, description, example)|
                  { name: name, type: type, description: description, example: example}
                end
              end

              unless optional.empty?
                link_schema_optional_properties = extract_attributes(@schema, optional).map do |(name, type, description, example)|
                  { name: name, type: type, description: description, example: example}
                end
              end
            end

            link['link_path'] = link_path
            link['required_properties'] = link_schema_required_properties || []
            link['optional_properties'] = link_schema_optional_properties || []
            link['example'] = generate_example(link, link_path)
            link['response'] = {
              header: generate_response_header(response_example, link),
              example: generate_response_example(response_example, link, resource)
            }
          end

          @processed_schema[resource] = schemata
        rescue => e
          $stdout.puts("Error in resource: #{resource}")
          raise e
        end
      end

      @processed_schema
    end

    private

    def extract_attributes(schema, properties)
      attributes = []

      _, properties = schema.dereference(properties)

      properties.each do |key, value|
        # found a reference to another element:
        _, value = schema.dereference(value)

        # include top level reference to nested things, when top level is nullable
        if value.has_key?('type') && value['type'].include?('null') && (value.has_key?('items') || value.has_key?('properties'))
          attributes << build_attribute(schema, key, value)
        end

        if value.has_key?('anyOf')
          descriptions = []
          examples = []

          anyof = value['anyOf']

          anyof.each do |ref|
            _, nested_field = schema.dereference(ref)
            descriptions << nested_field['description'] if nested_field['description']
            examples << nested_field['example'] if nested_field['example']
          end

          # avoid repetition :}
          description = if descriptions.size > 1
            descriptions.first.gsub!(/ of (this )?.*/, '')
            descriptions[1..-1].map { |d| d.gsub!(/unique /, '') }
            [descriptions[0...-1].join(', '), descriptions.last].join(' or ')
          else
            description = descriptions.last
          end

          example = [*examples].map { |e| "`#{e.to_json}`" }.join(' or ')
          attributes << [key, 'string', description, example]

        # found a nested object
        elsif value['properties']
          nested = extract_attributes(schema, value['properties'])
          nested.each do |attribute|
            attribute[0] = "#{key}:#{attribute[0]}"
          end
          attributes.concat(nested)

        elsif array_with_nested_objects?(value['items'])
          if value['items']['properties']
            nested = extract_attributes(schema, value['items']['properties'])
            nested.each do |attribute|
              attribute[0] = "#{key}/#{attribute[0]}"
            end
            attributes.concat(nested)
          end
          if value['items']['oneOf']
            value['items']['oneOf'].each_with_index do |oneof, index|
            ref,  oneof_definition = schema.dereference(oneof)
            oneof_name = ref ? ref.split('/').last : index
            nested = extract_attributes(schema, oneof_definition['properties'])
            nested.each do |attribute|
              attribute[0] = "#{key}/[#{oneof_name.upcase}].#{attribute[0]}"
            end
            attributes.concat(nested)
            end
        end

        # just a regular attribute
        else
          attributes << build_attribute(schema, key, value)
        end
      end
      attributes.map! { |key, type, description, example|
        if example.nil? && Prmd::DefaultExamples.key?(type)
          example = '`%s`' % Prmd::DefaultExamples[type].to_json
        end
        [key, type, description, example]
      }
      return attributes.sort
    end

    def extract_schemata_refs(schema, properties)
      ret = []
      properties.keys.sort.each do |key|
        value = properties[key]
        ref, value = schema.dereference(value)
        if value['properties']
          refs = extract_schemata_refs(schema, value['properties'])
        elsif value['items'] && value['items']['properties']
          refs = extract_schemata_refs(schema, value['items']['properties'])
        else
          refs = [ref]
        end
        if value.has_key?('type') && value['type'].include?('null') && (value.has_key?('items') || value.has_key?('properties'))
          # A nullable object usually isn't a reference to another schema. It's
          # either not a reference at all, or it's a reference within the same
          # schema. Instead, the definition of the nullable object might contain
          # references to specific properties.
          #
          # If all properties refer to the same schema, we'll use that as the
          # reference. This might even overwrite an actual, intra-schema
          # reference.

          l = refs.map { |v| v && v.split('/')[0..2] }
          if l.uniq.size == 1 && l[0] != nil
            ref = l[0].join('/')
          end
          ret << ref
        end
        ret.concat(refs)
      end
      ret
    end

    def build_attribute(schema, key, value)
      description = value['description'] || ''
      if value['default']
        description += "<br/> **default:** `#{value['default'].to_json}`"
      end

      if value['minimum'] || value['maximum']
        description += '<br/> **Range:** `'
        if value['minimum']
          comparator = value['exclusiveMinimum'] ? '<' : '<='
          description += "#{value['minimum'].to_json} #{comparator} "
        end
        description += 'value'
        if value['maximum']
          comparator = value['exclusiveMaximum'] ? '<' : '<='
          description += " #{comparator} #{value['maximum'].to_json}"
        end
        description += '`'
      end

      if value['enum']
        description += '<br/> **one of:**' + [*value['enum']].map { |e| "`#{e.to_json}`" }.join(' or ')
      end

      if value['pattern']
        description += "<br/> **pattern:** `#{value['pattern']}`"
      end

      if value['minLength'] || value['maxLength']
        description += '<br/> **Length:** `'
        if value['minLength']
          description += "#{value['minLength'].to_json}"
        end
        unless value['minLength'] == value['maxLength']
          if value['maxLength']
            unless value['minLength']
              description += '0'
            end
            description += "..#{value['maxLength'].to_json}"
          else
            description += '..∞'
          end
        end
        description += '`'
      end

      if value.has_key?('example')
        example = if value['example'].is_a?(Hash) && value['example'].has_key?('oneOf')
          value['example']['oneOf'].map { |e| "`#{e.to_json}`" }.join(' or ')
        else
          "`#{value['example'].to_json}`"
        end
      elsif (value['type'] == ['array'] && value.has_key?('items')) || value.has_key?('enum')
        example = "`#{schema.schema_value_example(value).to_json}`"
      elsif value['type'].include?('null')
        example = '`null`'
      end

      type = if value['type'].include?('null')
        'nullable '
      else
        ''
      end
      type += (value['format'] || (value['type'] - ['null']).first)
      [key, type, description, example]
    end


    def build_link_path(schema, link)
      link['href'].gsub(%r|(\{\([^\)]+\)\})|) do |ref|
        ref = ref.gsub('%2F', '/').gsub('%23', '#').gsub(%r|[\{\(\)\}]|, '')
        ref_resource = ref.split('#/definitions/').last.split('/').first.gsub('-', '_')
        identity_key, identity_value = schema.dereference(ref)
        if identity_value.has_key?('anyOf')
          '{' + ref_resource + '_' + identity_value['anyOf'].map { |r| r['$ref'].split('/').last }.join('_or_') + '}'
        else
          '{' + ref_resource + '_' + identity_key.split('/').last + '}'
        end
      end
    end

    def array_with_nested_objects?(items)
      return unless items
      items['properties'] || items['oneOf']
    end

    def generate_example(link, link_path)
      request = {}
      data = {}
      headers = {}

      path = link_path.gsub(/{([^}]*)}/) { |match| '$' + match.gsub(/[{}]/, '').upcase }
      get_params = []

      if link.has_key?('schema')
        data = @schema.schema_example(link['schema'])
        if link['method'].upcase == 'GET' && !data.nil?
          get_params << Prmd::UrlGenerator.new({schema: @schema, link: link, options: @options[:prmd]}).url_params
        end
      end

      data = nil if data.empty? # same thing

      # fetch any headers
      if link['method'].upcase != 'GET'
        opts = @options[:prmd].dup
        headers = { 'Content-Type' => opts[:content_type] }.merge(opts[:http_header])
      end

      # define initial request call
      if link['method'].upcase != 'GET'
        request = "-X #{link['method']} #{@schema.href}#{path}"
      else
        request = "#{@schema.href}#{path}"
      end

      # add data, if present
      if !data.nil? && link['method'].upcase != 'GET'
        data = "-d '#{pretty_json(data)}' \\"
      elsif !get_params.empty? && link['method'].upcase == 'GET'
        data = "-G #{get_params.join(" ss\\\n  -d ")} \\"
      end

      { request: request, data: data, http_headers: headers }
    end

    def generate_response_header(response_example, link)
      return response_example['head'] if response_example && response_example['head']

      header = 'HTTP/1.1'
      code = case true
      when link['code'] == 200
        '200 OK'
      when link['code'] == 201
        '201 Created'
      when link['code'] == 202
        '202 Accepted'
      when link['code'] == 204
        '204 No Content'
      when link['rel'] == 'create'
        '201 Created'
      when link['rel'] == 'destroy'
        '204 No Content'
      else
        '200 OK'
      end
      "#{header} #{code}"
    end

    def generate_response_example(response_example, link, resource)
      return response_example['body'] if response_example && response_example['body']

      if link.has_key?('targetSchema')
        pretty_json(@schema.schema_example(link['targetSchema']))
      elsif link['rel'] == 'instances'
        pretty_json([@schema.schemata_example(resource)])
      elsif link['code'] == 204
        nil
      else
        pretty_json(@schema.schemata_example(resource))
      end
    end

    def pretty_json(json)
      JSON.neat_generate(json, after_colon_1: 1, after_colon_n: 1, wrap: true, sort: true)
    end
  end
end
