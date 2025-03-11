# frozen_string_literal: true

class BitbucketServer
  class Model
    attr_reader :path, :connection

    def self.api(api = nil)
      return @api = api if api

      @api
    end

    def bbs_data
      @bbs_data ||= get
    end

    def new_model(model_class, **keywords)
      model_class.new(
        connection:   connection,
        parent_model: self,
        **keywords
      )
    end

    def new_relation(model_class, &get_proc)
      Relation.new(
        connection:   connection,
        model_class:  model_class,
        parent_model: self,
        get_proc:     get_proc
      )
    end

    private

    def request(http_method, *additional_paths, query: nil, **keywords)
      full_path = [*path, *additional_paths].compact

      keywords[:query] = query.compact if query_present?(query)
      add_default_api_if_not_present!(keywords)

      connection.send(http_method, *full_path, **keywords)
    end

    def get(*additional_paths, query: nil, **keywords)
      request(:get, *additional_paths, query: query, **keywords)
    end

    def head(*additional_paths, query: nil, **keywords)
      request(:head, *additional_paths, query: query, **keywords)
    end

    def query_present?(query)
      query.to_h.compact.present?
    end

    def add_default_api_if_not_present!(keywords)
      return if keywords.key?(:api)

      keywords[:api] = self.class.api if self.class.api
    end
  end
end
