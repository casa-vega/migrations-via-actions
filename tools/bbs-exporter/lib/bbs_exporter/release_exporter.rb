# frozen_string_literal: true

class BbsExporter
  class ReleaseExporter
    include Writable

    attr_reader :current_export, :repository_model, :tag

    delegate :archiver, :bitbucket_server, to: :current_export
    delegate :repository, to: :repository_model
    delegate :user, to: :bitbucket_server

    def initialize(current_export:, repository_model:, tag:, order: nil)
      @current_export = current_export
      @repository_model = repository_model
      @tag = tag
      @order = order
    end

    def commit
      repository_model.commit(tag["latestCommit"])
    end

    def bbs_model
      {
        tag:        tag,
        repository: repository,
        commit:     commit,
        user:       user
      }
    end

    def export
      serialize("release", bbs_model, @order)
    end
  end
end
