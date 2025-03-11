# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::PullRequestSerializer, :vcr do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(1)
  end

  let(:pull_request) do
    pull_request_model.pull_request
  end

  let(:repository) do
    repository_model.repository
  end

  let(:pull_request_data) do
    {
      repository: repository,
      pull_request: pull_request,
      description: pull_request["description"],
      merge_commit_sha: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  end

  describe "#serialize", :time_helpers do
    let(:pull_request_serializer) { described_class.new }
    subject { pull_request_serializer.serialize(pull_request_data) }

    it "returns a serialized Issue hash" do
      expected = {
          type: "pull_request",
          url: "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/1",
          repository: "https://example.com/projects/MIGR8/repos/hugo-pages",
          user: "https://example.com/users/dpmex4527",
          title: "Updated readme to test PR's in Bitbucket Server",
          body: %{Testing PR for Bitbucket Server},
          base: {
            ref: "master",
            sha: "9b14a132c4f6f27b1ef4bee034f79151d434756a",
            user: "https://example.com/projects/MIGR8",
            repo: "https://example.com/projects/MIGR8/repos/hugo-pages"
          },
          head: {
            ref: "test-pr",
            sha: "cab4b7ed6e2355d7dae94c94609f482f842e20b4",
            user: "https://example.com/projects/MIGR8",
            repo: "https://example.com/projects/MIGR8/repos/hugo-pages"
          },
          labels: [],
          merge_commit_sha: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          merged_at: "2019-04-22T23:24:58Z",
          closed_at: "2019-04-22T23:24:58Z",
          created_at: "2017-05-23T19:26:49Z"
        }

      expect(subject).to eq(expected)
    end

    context "with a closed merge request" do
      let(:pull_request) do
        repository_model.pull_request_model(3).pull_request
      end

      it "has a closed_at equal to updatedDate" do
        expect(subject[:closed_at]).to eq(
          format_long_timestamp(pull_request_data[:pull_request]["updatedDate"])
        )
      end
    end

    context "with a merged merge request" do
      let(:pull_request) do
        repository_model.pull_request_model(2).pull_request
      end

      it "has a merged_at and closed_at equal to updatedDate" do
        expect(subject[:closed_at]).to eq(
          format_long_timestamp(pull_request["updatedDate"])
        )

        expect(subject[:merged_at]).to eq(
          format_long_timestamp(pull_request["updatedDate"])
        )
      end
    end
  end
end
