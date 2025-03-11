# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::ArchiveBuilder, :archive_helpers do
  let(:project_model) { bitbucket_server.project_model("MIGR8") }
  let(:repository_model) { project_model.repository_model("hugo-pages") }
  let(:repository) { repository_model.repository }

  let(:project_model_651) { bitbucket_server.project_model("BBS651") }
  let(:repository_model_651) { project_model_651.repository_model("empty-repo") }
  let(:repository_651) { repository_model_651.repository }

  let(:tarball_path) { Tempfile.new("string").path }
  let(:files) { file_list_from_archive(tarball_path) }

  let(:git) { archive_builder.send(:git) }

  subject(:archive_builder) { described_class.new(current_export: current_export) }

  # Call BbsExporter::ArchiveBuilder#current_export to initialize database connection.
  before(:each) { archive_builder.current_export }

  describe "#create_tar" do
    subject(:create_tar) { archive_builder.create_tar(tarball_path) }

    it "makes a tarball with a json file" do
      ExtractedResource.create(model_type: "user", model_url: "https://example.com", data: {"foo" => "bar"}.to_json)
      archive_builder.write_files

      create_tar

      expect(files).to include("users_000001.json")
    end

    it "adds a schema.json" do
      create_tar

      expect(files).to include("schema.json")

      dir = Dir.mktmpdir "archive_builder"

      json_data = read_file_from_archive(tarball_path, "schema.json")
      expect(JSON.load(json_data)).to eq({"version" => "1.2.0"})
    end

    it "adds a urls.json" do
      create_tar

      expect(files).to include("urls.json")
    end
  end

  describe "#clone_repo", :vcr do
    let(:expected_clone_url) { "https://unit-test@example.com/scm/migr8/hugo-pages.git" }

    subject(:clone_repo) { archive_builder.clone_repo(repository) }

    it "can create a clone url" do
      expect(git).to receive(:clone).with(hash_including(url: expected_clone_url))

      clone_repo
    end
  end

  describe "#create_branch", :vcr do
    let(:create_branch_repository) { repository_651 }
    let(:name) { "example-branch-name" }
    let(:target) { "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }

    let(:repo_path) { archive_builder.repo_path(create_branch_repository) }

    subject(:create_branch) do
      archive_builder.create_branch(
        repository: create_branch_repository,
        name: name,
        target: target
      )
    end

    it "calls BbsExporter::Git#create_branch" do
      expect(git).to receive(:create_branch).with(
        path: repo_path,
        name: name,
        target: target
      )

      create_branch
    end
  end

  describe "#repo_clone_url", :vcr do
    let(:repo_clone_url_repository) { repository_651 }
    let(:user) { "synthead" }

    subject(:link) do
      archive_builder.send(
        :repo_clone_url,
        repo_clone_url_repository,
        user: user
      )
    end

    it { should eq("https://synthead@example.com/scm/bbs651/empty-repo.git") }

    context "when user is \" @#:\"" do
      let(:user) { " @#:" }

      it { should eq("https://+%40%23%3A@example.com/scm/bbs651/empty-repo.git") }
    end

    context "when user param is not present" do
      subject(:link) { archive_builder.send(:repo_clone_url, repo_clone_url_repository) }

      it { should eq("https://unit-test@example.com/scm/bbs651/empty-repo.git") }
    end
  end
end
