# frozen_string_literal: true

class BbsExporter
  class ReleaseSerializer < BaseSerializer
    validates_presence_of :tag, :repository, :user, :commit, :display_id,
      :author_timestamp

    def to_gh_hash
     {
       type:             type,
       url:              url,
       repository:       repository_url,
       user:             user_url,
       name:             display_id,
       tag_name:         display_id,
       body:             body,
       state:            state,
       pending_tag:      display_id,
       prerelease:       prerelease,
       target_commitish: target_commitish,
       release_assets:   release_assets,
       published_at:     author_timestamp_formatted,
       created_at:       author_timestamp_formatted
     }
    end

    private

    def type
      "release"
    end

    def tag
      bbs_model[:tag]
    end

    def repository
      bbs_model[:repository]
    end

    def user
      bbs_model[:user]
    end

    def commit
      bbs_model[:commit]
    end

    def display_id
      tag["displayId"]
    end

    def author_timestamp
      commit["authorTimestamp"]
    end

    def url
      url_for_model(bbs_model, type: type)
    end

    def user_url
      url_for_model(user, type: "user")
    end

    def repository_url
      url_for_model(bbs_model, type: "repository")
    end

    def target_commitish
      "master"
    end

    def prerelease
      false
    end

    def state
      "published"
    end

    def body
      ""
    end

    def release_assets
      []
    end

    def author_timestamp_formatted
      format_long_timestamp(author_timestamp)
    end
  end
end
