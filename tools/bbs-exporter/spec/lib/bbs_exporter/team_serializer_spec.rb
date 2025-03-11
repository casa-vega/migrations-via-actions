# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::TeamSerializer, :vcr do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:project) do
    project_model.project
  end

  let(:user) do
    bitbucket_server.user
  end

  let(:repository) do
    repository_model.repository
  end

  let(:model_url_service) do
    BbsExporter::ModelUrlService.new
  end

  let(:repository_url) do
    model_url_service.url_for_model(
      { repository: repository },
      type: "repository"
    )
  end

  let(:user_url) do
    model_url_service.url_for_model(user)
  end

  subject(:serializer) { described_class.new }

  describe "#serialize", :time_helpers do
    subject { serializer.serialize(team) }

    context "when provided a team with no inherited permissions" do
      let(:team) do
        {
          "name"         => "Project read access",
          "project"      => project,
          "permissions"  => ["REPO_READ"],
          "members"      => [user_url],
          "repositories" => [repository_url]
        }
      end

      it "returns a serialized Team hash" do
        expected = {
          "type" => "team",
          "url" => "https://example.com/admin/groups/view?name=Project+read+access#MIGR8",
          "organization" => "https://example.com/projects/MIGR8",
          "name" => "Project read access",
          "permissions" => [
            {
              "repository" => "https://example.com/projects/MIGR8/repos/hugo-pages",
              "access" => "pull"
            }
          ],
          "members" => [
            {
              "user" => "https://example.com/users/unit-test",
              "role" => "member",
            },
          ],
          "created_at" => current_time
        }

        expect(subject).to eq(expected)
      end
    end

    context "when provided a team with inherited permissions" do
      let(:team) do
        {
          "name"         => "Project write access",
          "project"      => project,
          "permissions"  => ["PROJECT_WRITE", "REPO_READ"],
          "members"      => [user_url],
          "repositories" => [repository_url]
        }
      end

      it "returns a serialized Team hash" do
        expected = {
          "type" => "team",
          "url" => "https://example.com/admin/groups/view?name=Project+write+access#MIGR8",
          "organization" => "https://example.com/projects/MIGR8",
          "name" => "Project write access",
          "permissions" => [
            {
              "repository" => "https://example.com/projects/MIGR8/repos/hugo-pages",
              "access" => "push"
            }
          ],
          "members" => [
            {
              "user" => "https://example.com/users/unit-test",
              "role" => "member",
            },
          ],
          "created_at" => current_time
        }

        expect(subject).to eq(expected)
      end
    end
  end
end
