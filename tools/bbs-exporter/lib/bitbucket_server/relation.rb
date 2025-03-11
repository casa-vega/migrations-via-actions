# frozen_string_literal: true

class BitbucketServer
  class Relation
    include Enumerable

    attr_reader :connection, :model_class, :get_proc, :parent_model

    def initialize(connection:, model_class:, get_proc:, parent_model: nil)
      @connection = connection
      @model_class = model_class
      @get_proc = get_proc
      @parent_model = parent_model
    end

    def models
      @models ||= bbs_data.map do |bbs_data_item|
        model_class.new(
          connection:   connection,
          bbs_data:     bbs_data_item,
          parent_model: parent_model
        )
      end
    end

    def each
      return models.to_enum unless block_given?

      models.each do |model|
        yield model
      end
    end

    def bbs_data
      get_proc.call
    end
  end
end
