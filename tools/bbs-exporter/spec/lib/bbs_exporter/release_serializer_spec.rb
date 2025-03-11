# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::ReleaseSerializer, :vcr do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:tag) do
    repository_model.tag("end-of-sinatra")
  end

  let(:repository) do
    repository_model.repository
  end

  let(:commit) do
    repository_model.commit(tag["latestCommit"])
  end

  let(:user) do
    bitbucket_server.user
  end

  let(:bbs_model) do
    {
      tag:        tag,
      repository: repository,
      commit:     commit,
      user:       user
    }
  end

  describe "#serialize" do
    subject { described_class.new.serialize(bbs_model) }

    it "returns a serialized release hash" do
      expected = {
        type:              "release",
        url:               "https://example.com/projects/MIGR8/repos/hugo-pages/browse?at=refs%2Ftags%2Fend-of-sinatra",
        repository:        "https://example.com/projects/MIGR8/repos/hugo-pages",
        user:              "https://example.com/users/unit-test",
        name:              "end-of-sinatra",
        tag_name:          "end-of-sinatra",
        body:              "",
        state:             "published",
        pending_tag:       "end-of-sinatra",
        prerelease:        false,
        target_commitish:  "master",
        release_assets:    [],
        published_at:      "2016-05-10T13:06:10Z",
        created_at:        "2016-05-10T13:06:10Z"
      }

      expect(subject).to eq(expected)
    end
  end
end
