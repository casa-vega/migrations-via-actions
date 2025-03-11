# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::ModelUrlService, :vcr do
  let(:repository_model) do
    bitbucket_server.project_model("MIGR8").repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(1)
  end

  let(:user) do
    bitbucket_server.user
  end

  let(:project) do
    repository_model.project_model.project
  end

  let(:repository) do
    repository_model.repository
  end

  let(:pull_request) do
    pull_request_model.pull_request
  end

  let(:activities) do
    pull_request_model.activities
  end

  let(:tag) do
    repository_model.tag("refs/tags/=l")
  end

  describe "#url_for_model", :pull_request_helpers do
    it "returns a correct URL for a user" do
      url = subject.url_for_model(user, type: "user")

      expect(url).to eq("https://example.com/users/unit-test")
    end

    it "returns a correct URL for a user when a link is not available" do
      user_model = {
        user:       user,
        repository: repository
      }

      url = subject.url_for_model(user_model, type: "user")

      expect(url).to eq("https://example.com/users/unit-test")
    end

    it "returns a correct URL for a project" do
      url = subject.url_for_model(project)

      expect(url).to eq("https://example.com/projects/MIGR8")
    end

    it "returns a correct URL for an issue comment" do
      activity = comment_activity_start_with(
        activities,
        "Comment on this thing"
      )

      bbs_model = {
        pull_request:         pull_request,
        pull_request_comment: activity["comment"]
      }

      url = subject.url_for_model(bbs_model, type: "issue_comment")

      expect(url).to eq(
        "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1" \
        "/overview?commentId=11"
      )
    end

    it "returns a correct URL for a repository" do
      url = subject.url_for_model(repository)

      expect(url).to eq(
        "https://example.com/projects/MIGR8/repos/hugo-pages/browse"
      )
    end

    it "returns a correct URL for a release with a tag named \"=l\"" do
      release_model = {
        repository: repository,
        tag:        tag
      }

      url = subject.url_for_model(release_model, type: "release")

      expect(url).to eq(
        "https://example.com/projects/MIGR8/repos/hugo-pages/browse" \
        "?at=refs%2Ftags%2F%3Dl"
      )
    end
  end
end
