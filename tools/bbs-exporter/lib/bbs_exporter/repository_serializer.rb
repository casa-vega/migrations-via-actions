# frozen_string_literal: true

class BbsExporter
  # Serializes Repositories from Bitbucket Server's Projects.
  class RepositorySerializer < BaseSerializer
    validates_inclusion_of :repo_public?, in: [true, false]
    validates_presence_of :repository, :project, :name

    def to_gh_hash
      {
        type:           type,
        url:            url,
        owner:          owner_url,
        name:           name,
        description:    description,
        private:        project_and_repo_private?,
        has_issues:     has_issues,
        has_wiki:       has_wiki,
        has_downloads:  has_downloads,
        labels:         labels,
        collaborators:  serialized_collaborators,
        created_at:     created_at,
        git_url:        git_url,
        default_branch: default_branch,
        public_keys:    public_keys
      }
    end

    private

    def remove_control_characters(input)
      input&.gsub(/[[:cntrl:]]/, "")
    end

    def type
      "repository"
    end

    def repository
      bbs_model[:repository]
    end

    def project
      repository["project"]
    end

    def access_keys
      bbs_model[:access_keys]
    end

    def collaborators
      bbs_model[:collaborators]
    end

    def name
      repository["slug"]
    end

    def description
      remove_control_characters(repository["description"])
    end

    def project_public?
      project["public"]
    end

    def repo_public?
      repository["public"]
    end

    def url
      url_for_model(bbs_model, type: "repository")
    end

    def has_issues
      false
    end

    def has_wiki
      false
    end

    def has_downloads
      false
    end

    def labels
      []
    end

    def default_branch
      "master"
    end

    def owner_url
      url_for_model(project) if project
    end

    def project_and_repo_private?
      !(project_public? || repo_public?)
    end

    def serialized_collaborators
      collaborators.to_a.map do |repository_team_member|
        CollaboratorSerializer.new.serialize(repository_team_member)
      end
    end

    def public_keys
      access_keys.map do |access_key|
        {
          "title"       => access_key.label,
          "key"         => access_key.text,
          "read_only"   => access_key.read_only?,
          "fingerprint" => access_key.fingerprint,
          "created_at"  => created_at
        }
      end
    end

    def created_at
      @created_at ||= generate_created_at
    end

    def git_url
      "tarball://root/repositories/#{project["key"] + "/" + repository["slug"]}.git"
    end
  end
end
