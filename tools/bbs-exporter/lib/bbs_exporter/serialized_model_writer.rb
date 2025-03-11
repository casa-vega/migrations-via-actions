# frozen_string_literal: true

require "active_support/inflector/inflections"

class BbsExporter
  class SerializedModelWriter
    PAGE_SIZE = 100

    def initialize(dir, model_type)
      @dir = dir
      @model_type = model_type
    end

    attr_reader :dir, :prefix

    def write_models
      continue = true

      while continue
        resources = ExtractedResource.resources(@model_type, PAGE_SIZE, index)

        break if resources.blank?

        self.count += resources.size
        contents = resources.map { |resource| JSON.parse(resource.data) }

        write_json_file(build_filename, contents)

        continue = contents.size == PAGE_SIZE
        self.index += 1
      end

      count
    end

    # Write a hash to a JSON file
    #
    # @param [String] path the path to the file to be written
    # @param [Hash] contents the Hash to be converted to JSON and written to
    #   file
    def write_json_file(path, contents)
      File.open(path, "w") do |file|
        file.write(JSON.pretty_generate(contents))
      end
    end

    # Generates the name of the current archive file.
    #
    # e.g. "users_000023.json"
    def build_filename
      "%s/%s_%06d.json" % [dir, @model_type.pluralize, index]
    end

    # The number of records in the current file.
    def count
      @count ||= 0
    end
    attr_writer :count

    # The number of the current file.
    def index
      @index ||= 1
    end
    attr_writer :index
  end
end
