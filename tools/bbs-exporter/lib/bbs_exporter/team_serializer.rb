# frozen_string_literal: true

class BbsExporter
  # Serializes Teams from data collected by `TeamBuilder`.
  class TeamSerializer < BaseSerializer
    validates_presence_of :project, :name

    PERMISSION_MAP = {
      "PROJECT_READ"  => { "order" => 0, "value" => "pull" },
      "PROJECT_WRITE" => { "order" => 1, "value" => "push" },
      "PROJECT_ADMIN" => { "order" => 2, "value" => "admin" },

      "REPO_READ"     => { "order" => 0, "value" => "pull" },
      "REPO_WRITE"    => { "order" => 1, "value" => "push" },
      "REPO_ADMIN"    => { "order" => 2, "value" => "admin" }
    }

    def to_gh_hash
      {
        "type"         => type,
        "url"          => url,
        "organization" => project_url,
        "name"         => name,
        "permissions"  => repository_permissions,
        "members"      => member_permissions,
        "created_at"   => created_at
      }
    end

    private

    def type
      "team"
    end

    def project
      bbs_model["project"]
    end

    def name
      bbs_model["name"]
    end

    def permissions
      bbs_model["permissions"]
    end

    def repositories
      bbs_model["repositories"]
    end

    def members
      bbs_model["members"]
    end

    def url
      url_for_model(bbs_model, type: type)
    end

    def project_url
      model_url_service.url_for_model(project)
    end

    def repository_permissions
      repositories.map do |repository|
        {
          "repository" => repository,
          "access"     => permissions_mapped
        }
      end
    end

    def permissions_mapped
      # Use broadest access from permissions
      PERMISSION_MAP.
        select { |k, v| permissions.include? k }.
        max_by { |k, v| v["order"] }[1]["value"]
    end

    def member_permissions
      members.map do |member|
        {
          "user" => member,
          "role" => "member"
        }
      end
    end

    def created_at
      generate_created_at
    end
  end
end
