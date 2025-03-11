# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::RepositoryExporter do
  subject(:repository_exporter) do
    described_class.new(
      repository_model: repository_model,
      current_export:   current_export
    )
  end

  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:empty_repository_model) do
    project_model.repository_model("empty-repo")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(6)
  end

  let(:empty_repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model: empty_repository_model,
      current_export:   current_export
    )
  end

  describe "#export", :vcr do
    it "should not export branch permissions for empty repos" do
      expect(
        BbsExporter::BranchPermissionsExporter
      ).to_not receive(:export)

      empty_repository_exporter.export_protected_branches
    end

    context "when repo is empty" do
      before do
        allow_any_instance_of(BbsExporter::ArchiveBuilder)
           .to receive(:clone_repo)
      end

      let(:project_model) do
        bitbucket_server.project_model("MEC")
      end

      let(:empty_repository_model) do
        project_model.repository_model("test-empty-repo")
      end

      it "should export project" do
        expect(
          empty_repository_exporter
        ).to receive(:export_repository_project)

        empty_repository_exporter.export
      end
    end

    context "when skipping teams" do
      before do
        current_export.options[:models] = %w()
        allow_any_instance_of(BbsExporter::ArchiveBuilder)
          .to receive(:clone_repo)
      end

      it "does not build out repo group access list" do
        expect(repository_exporter).to_not receive(:group_access)
        repository_exporter.export
      end
    end
  end

  describe "#export_optional_models" do
    subject(:export_optional_models) do
      repository_exporter.export_optional_models
    end

    context "with teams included in optional models" do
      before do
        current_export.options[:models] = %w(teams)
      end

      it "exports teams" do
        expect(repository_exporter).to receive(:export_teams)
        export_optional_models
      end
    end

    context "with commit comments included in optional models" do
      before do
        current_export.options[:models] = %w(commit_comments)
      end

      it "exports commit comments" do
        expect(repository_exporter).to receive(:export_commit_comments)
        export_optional_models
      end
    end

    context "with models omitted from optional models" do
      before do
        current_export.options[:models] = %w()
      end

      it "does not export teams" do
        expect(repository_exporter).to_not receive(:export_teams)
        export_optional_models
      end

      it "does not build out repo group permissions" do
        expect(repository_exporter).to_not receive(:group_access)
        export_optional_models
      end

      it "does not export commit comments" do
        expect(repository_exporter).to_not receive(:export_commit_comments)
        export_optional_models
      end
    end
  end

  describe "#export_teams", :vcr do
    it "serializes teams correctly" do
      team_model_project_read_repo_write_access = {
        "name"         => "Project_read Access",
        "project"      => {
          "key"         => "MIGR8",
          "id"          => 2,
          "name"        => "Migrate Me",
          "description" => "Test project description",
          "public"      => false,
          "type"        => "NORMAL",
          "links"       => {
            "self" => [
              { "href" => "https://example.com/projects/MIGR8" }
            ]
          }
        },
        "permissions"  => ["PROJECT_READ", "REPO_WRITE"],
        "members"      => ["https://example.com/users/synthead"],
        "repositories" => [
          "https://example.com/projects/MIGR8/repos/hugo-pages"
        ]
      }

      team_model_project_read_access = {
        "name"         => "project_read_access",
        "project"      => {
          "key"         => "MIGR8",
          "id"          => 2,
          "name"        => "Migrate Me",
          "description" => "Test project description",
          "public"      => false,
          "type"        => "NORMAL",
          "links"       => {
            "self" => [
              { "href" => "https://example.com/projects/MIGR8" }
            ]
          }
        },
        "permissions"  => ["PROJECT_READ"],
        "members"      => ["https://example.com/users/unit-test"],
        "repositories" => [
          "https://example.com/projects/MIGR8/repos/hugo-pages"
        ]
      }

      team_model_stash_users = {
        "name"         => "stash-users",
        "project"      => {
          "key"         => "MIGR8",
          "id"          => 2,
          "name"        => "Migrate Me",
          "description" => "Test project description",
          "public"      => false,
          "type"        => "NORMAL",
          "links"       => {
            "self" => [
              { "href" => "https://example.com/projects/MIGR8" }
            ]
          }
        },
        "permissions"  => ["PROJECT_ADMIN", "REPO_READ"],
        "members"      => [
          "https://example.com/users/admiralawkbar",
          "https://example.com/users/chocrates",
          "https://example.com/users/dpmex4527",
          "https://example.com/users/has_weird%F0%9F%8C%ADcharacters",
          "https://example.com/users/has_weird%F0%9F%8C%ADcharacters0",
          "https://example.com/users/jfine",
          "https://example.com/users/jwiebalk",
          "https://example.com/users/kylemacey",
          "https://example.com/users/larsxschneider",
          "https://example.com/users/mattcantstop",
          "https://example.com/users/michaelsainz",
          "https://example.com/users/migarjo",
          "https://example.com/users/primetheus",
          "https://example.com/users/steffen",
          "https://example.com/users/synthead",
          "https://example.com/users/tambling",
          "https://example.com/users/test123",
          "https://example.com/users/testuser1",
          "https://example.com/users/testuser2",
          "https://example.com/users/testuser3",
          "https://example.com/users/testuser4",
          "https://example.com/users/testuser5",
          "https://example.com/users/testuser6",
          "https://example.com/users/testuser7",
          "https://example.com/users/unit-test"
        ],
        "repositories" => [
          "https://example.com/projects/MIGR8/repos/hugo-pages"
        ]
      }

      allow(repository_exporter).to receive(:serialize)
      expect(repository_exporter).to receive(:serialize).with(
        "team",
        team_model_project_read_repo_write_access
      )
      expect(repository_exporter).to receive(:serialize).with(
        "team",
        team_model_project_read_access
      )
      expect(repository_exporter).to receive(:serialize).with(
        "team",
        team_model_stash_users
      )

      repository_exporter.export_teams
    end
  end

  describe "#export_repository_project", :vcr do
    context "with a user repository" do
      let(:repository_model) do
        bitbucket_server.project_model("~kylemacey").repository_model("personal-repo")
      end

      subject(:export_repository_project) do
        repository_exporter.export_repository_project
      end

      it "exports the owning user" do
        expect(repository_exporter).to(
          receive(:serialize).with("user", hash_including("name" => "kylemacey"))
        )
        export_repository_project
      end
    end
  end

  describe "#commits_with_comments", :vcr do
    it "contains a unique commit from the commit-comments-not-master branch" do
      commit = repository_exporter.commits_with_comments.detect do |commit|
        commit["id"] == "2b912a8ca196cd92cd351ef4fba52e5cedbfb734"
      end

      expect(commit).to_not eq(nil)
    end

    it "logs when loading commits takes a long time" do
      stub_const("BbsExporter::RepositoryExporter::COMMIT_COMMENT_SCAN_CONSIDERED_SLOW_IN_SECONDS", -1)

      expect(current_export.output_logger).to receive(:warn).with(
        "Exporting commit comments is taking a long time. This usually happens when a repository has a very large number of commits. If you don't need to export commit comments, kill this command and re-run with the `--except commit_comments` option."
      )

      repository_exporter.commits_with_comments
    end
  end
end
