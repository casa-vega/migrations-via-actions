# frozen_string_literal: true

class BitbucketServer
  class RepositoryAccessKey < Model
    api :ssh
    attr_reader :repository

    def initialize(connection:, parent_model:, bbs_data: nil, id: nil)
      @connection = connection
      @repository = parent_model
      @bbs_data = bbs_data
      @id = id
    end

    def id
      @id ||= bbs_data["key"]["id"]
    end

    def path
      [*repository.path, "ssh", id.to_s]
    end

    def label
      bbs_data["key"]["label"]
    end

    def text
      bbs_data["key"]["text"]
    end

    def fingerprint
      SSHFingerprint.compute(text)
    end

    def read_only?
      bbs_data["permission"] == "REPO_READ"
    end
  end
end
