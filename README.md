# json-schema-docs

Inspired by [prmd](https://github.com/interagent/prmd)'s doc generation, this is a stand-alone gem to generate Markdown files from a single JSON schema file. `prmd`'s doc generator is rather opinionated, and I did not like its opinions. 😅

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'json-schema-docs'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install json-schema-docs

## Usage

``` ruby
# pass in a filename
JsonSchemaDocs.build(filename: filename)

# or pass in a string
JsonSchemaDocs.build(schema: contents)

# or a schema class
schema = Prmd::Schema.new(data)
JsonSchemaDocs.build(schema: schema)
```


## Breakdown

There are several phases going on the single `JsonSchemaDocs.build` call:

* The JSON schema file is read (if you passed `filename`) through `Prmd::Schema` (or simply consumed if you passed it through `schema`).
* `JsonSchemaDocs::Parser` manipulates the schema into a slightly saner format.
* `JsonSchemaDocs::Generator` takes that saner format and converts it into Markdown, via ERB templates.

If you wanted to, you could break these calls up individually. For example:

``` ruby
options = {}
options[:filename] = "#{File.dirname(__FILE__)}/../data/schema.json"

options = JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS.merge(options)

response = File.read(options[:filename])

parser = JsonSchemaDocs::Parser.new(response, options)
parsed_schema = parser.parse

generator = JsonSchemaDocs::Generator.new(parsed_schema, options)

generator.generate
```

## Generating output

By default, the generation process uses ERB to layout the content into Markdown.

### Helper methods

In your ERB layouts, there are several helper methods you can use. The helper methods are:

* `slugify(str)` - This slugifies the given string.
* `include(filename, opts)` - This embeds a template from your `includes` folder, passing along the local options provided.

## Configuration

The following options are available:

| Option | Description | Default |
| :----- | :---------- | :------ |
| `filename` | The location of your schema's IDL file. | `nil` |
| `schema` | A string representing a schema IDL file. | `nil` |
| `delete_output` | Deletes `output_dir` before generating content. | `false` |
| `output_dir` | The location of the output Markdown files. | `./output/` |
| `templates` | The templates to use when generating Markdown files. You may override any of the following keys: `endpoint`, `object`, `includes`. | The defaults are found in _lib/json-schema-docs/layouts/_.
| `prmd` | The options to pass into PRMD's parser. | The defaults are found in _lib/json-schema-docs/configuration.rb/_.

## Development

After checking out the repo, run `script/bootstrap` to install dependencies. Then, run `rake test` to run the tests. You can also run `bundle exec rake console` for an interactive prompt that will allow you to experiment.

## Sample site

Clone this repository and run:

```
bundle exec rake sample
```

to see some sample output.
