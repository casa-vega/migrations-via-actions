# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::PullRequest do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(1)
  end

  describe "#diff" do
    context "with a file_path that contains slashes" do
      subject(:diff) do
        pull_request_model.diff("path/with/slashes")
      end

      it "splits the path " do
        expect(pull_request_model).to receive(:get).with(
          "diff", "path", "with", "slashes", anything
        )

        diff
      end
    end
  end
end
