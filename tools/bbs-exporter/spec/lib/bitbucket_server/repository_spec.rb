# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::Repository do
  let(:project_model) do
    bitbucket_server.project_model("BBS486")
  end

  let(:repository_model) do
    project_model.repository_model("empty-repo")
  end

  let(:commits_404) do
    repository_model.commits
  end

  describe "#commits", :vcr do
    it "returns an empty array for 404s" do
      expect(commits_404).to eq([])
    end
  end

  describe "#diff" do
    context "with a file_path that contains slashes" do
      subject(:diff) do
        repository_model.diff(
          "to_hash",
          file_path: "path/with/slashes",
        )
      end

      it "splits the path " do
        expect(repository_model).to receive(:get).with(
          "commits", "to_hash", "diff", "path", "with", "slashes", anything
        )

        diff
      end
    end
  end
end
