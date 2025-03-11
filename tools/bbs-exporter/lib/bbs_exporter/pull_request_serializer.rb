# frozen_string_literal: true

class BbsExporter
  # Serializes Pull Requests from Bitbucket Server's Pull Requests.
  class PullRequestSerializer < BaseSerializer
    validates_presence_of :author, :created_date, :from_ref,
      :from_ref_display_id, :from_ref_latest_commit, :project, :repository,
      :state, :to_ref, :to_ref_display_id, :to_ref_latest_commit, :updated_date

    def to_gh_hash
      {
        type: type,
        url: url,
        user: author_url,
        repository: repository_url,
        title: title,
        body: body,
        base: base,
        head: head,
        merge_commit_sha: merge_commit_sha,
        labels: labels,
        merged_at: merged_at,
        closed_at: closed_at,
        created_at: created_date_formatted
      }
    end

    private

    def type
      "pull_request"
    end

    def pull_request
      bbs_model[:pull_request]
    end

    def author
      pull_request["author"]["user"]
    end

    def repository
      bbs_model[:repository]
    end

    def project
      repository["project"]
    end

    def state
      pull_request["state"]
    end

    def created_date
      pull_request["createdDate"]
    end

    def updated_date
      pull_request["updatedDate"]
    end

    def to_ref
      pull_request["toRef"]
    end

    def from_ref
      pull_request["fromRef"]
    end

    def title
      pull_request["title"].to_s
    end

    def body
      bbs_model[:description].to_s
    end

    def to_ref_display_id
      to_ref["displayId"]
    end

    def to_ref_latest_commit
      to_ref["latestCommit"]
    end

    def from_ref_display_id
      from_ref["displayId"]
    end

    def from_ref_latest_commit
      from_ref["latestCommit"]
    end

    def url
      url_for_model(bbs_model, type: type)
    end

    def project_url
      url_for_model(project)
    end

    def author_url
      url_for_model(author, type: "user")
    end

    def repository_url
      url_for_model(bbs_model, type: "repository")
    end

    def merged?
      state == "MERGED"
    end

    def declined?
      state == "DECLINED"
    end

    def base
      {
        ref:  to_ref_display_id,
        sha:  to_ref_latest_commit,
        user: project_url,
        repo: repository_url
      }
    end

    def head
      {
        ref:  from_ref_display_id,
        sha:  from_ref_latest_commit,
        user: project_url,
        repo: repository_url
      }
    end

    def merge_commit_sha
      bbs_model[:merge_commit_sha]
    end

    def labels
      []
    end

    def created_date_formatted
      format_long_timestamp(created_date)
    end

    def updated_date_formatted
      format_long_timestamp(updated_date)
    end

    def merged_at
      updated_date_formatted if merged?
    end

    def closed_at
      updated_date_formatted if declined? || merged?
    end
  end
end
