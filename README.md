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
* `JsonSchemaDocs::Generator` takes that saner format and  begins the process of applying items to the HTML templates.
* `JsonSchemaDocs::Renderer` technically runs as part of the generation phase. It passes the contents of each page and converts it into HTML.

If you wanted to, you could break these calls up individually. For example:

``` ruby
options = {}
options[:filename] = "#{File.dirname(__FILE__)}/../data/schema.json"

options = JsonSchemaDocs::Configuration::JSON_SCHEMA_DOCS_DEFAULTS.merge(options)

response = File.read(options[:filename])

parser = JsonSchemaDocs::Parser.new(response, options)
parsed_schema = parser.parse

generator = JsonSchemaDocs::Generator.new(parsed_schema, options)

generator.generate
```

## Generating output

By default, the generation process uses ERB to layout the content. There are a bunch of default options provided for you, but feel free to override any of these. The *Configuration* section below has more information on what you can change.

It also uses [html-pipeline](https://github.com/jch/html-pipeline) to perform the rendering by default. You can override this by providing a custom rendering class.You must implement two methods:

* `initialize` - Takes two arguments, the parsed `schema` and the configuration `options`.
* `render` Takes the contents of a template page. It also takes an optional kwargs, `meta`, for anything you want to include in your template. For example:

``` ruby
class CustomRenderer
  def initialize(parsed_schema, options)
    @parsed_schema = parsed_schema
    @options = options
  end

  def render(contents, meta: {})
    contents = contents.sub(/Repository/i, '<strong>Meow Woof!</strong>')
    opts = meta.merge({ foo: "bar" })

    @default_layout.result(OpenStruct.new(opts).instance_eval { binding })
  end
end

options[:filename] = 'location/to/schema.json'
options[:renderer] = CustomRenderer

JsonSchemaDocs.build(options)
```

If your `render` method returns `nil`, the `Generator` will not attempt to write any HTML file.

### Helper methods

In your ERB layouts, there are several helper methods you can use. The helper methods are:

* `slugify(str)`: This slugifies the given string.
* `include(filename, opts)`: This embeds a template from your `includes` folder, passing along the local options provided.
* `markdownify(string)`: This converts a string into HTML via CommonMarker.
* `types`: Collections of the various types.
* `schemata(name)`: The schemata defined by `name`.

To call these methods within templates, you must use the dot notation, such as `<%= slugify.(text) %>`.

## Configuration

The following options are available:

| Option | Description | Default |
| :----- | :---------- | :------ |
| `filename` | The location of your schema's JSON file. | `nil` |
| `schema` | A string representing a schema JSON file. | `nil` |
| `output_dir` | The location of the output HTML files. | `./output/` |
| `use_default_styles` | Indicates if you want to use the default styles. | `true` |
| `base_url` | Indicates the base URL to prepend for assets and links. | `""` |
| `delete_output` | Deletes `output_dir` before generating content. | `false` |
| `pipeline_config` | Defines two sub-keys, `pipeline` and `context`, which are used by `html-pipeline` when rendering your output. |  The defaults are found in _lib/json-schema-docs/configuration.rb/_ |
| `renderer` | The rendering class to use. | `JsonSchemaDocs::Renderer`
| `templates` | The templates to use when generating HTML. You may override any of the following keys: `default`, `links`, `resource`. | The defaults are found in _lib/json-schema-docs/layouts/_.
| `landing_pages` | The landing page to use when generating HTML for each type. You may override any of the following keys: `index`. | The defaults are found in _lib/json-schema-docs/landing\_pages/_.
| `prmd` | The options to pass into PRMD's parser. | The defaults are found in _lib/json-schema-docs/configuration.rb/_.

## Development

After checking out the repo, run `script/bootstrap` to install dependencies. Then, run `rake test` to run the tests. You can also run `bundle exec rake console` for an interactive prompt that will allow you to experiment.

## Sample site

Clone this repository and run:

```
bundle exec rake sample
```

to see some sample output.
