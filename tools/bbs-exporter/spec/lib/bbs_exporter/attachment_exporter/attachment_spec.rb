# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::AttachmentExporter::Attachment do
  let(:project_model) { bitbucket_server.project_model("MIGR8") }
  let(:repository_model) { project_model.repository_model("hugo-pages") }
  let(:repository) { repository_model.repository }
  let(:link) { "attachment:6/328eabcebf%2Foctocat.png" }
  let(:tooltip) { " 'octocat'" }

  let(:attachment) do
    described_class.new(
      link: link,
      tooltip: tooltip,
      repository_model: repository_model,
      archiver: current_export.archiver
    )
  end

  describe "#repository_id", :vcr do
    subject(:repository_id) { attachment.repository_id }

    it { should eq("6") }
  end

  describe "#filename" do
    subject(:filename) { attachment.filename }

    it { should eq("131b93cdc85108ef1c75907eaf5bd5ae.png") }
  end

  describe "#path" do
    subject(:path) { attachment.path }

    it { should eq(["328eabcebf", "octocat.png"]) }

    context "when link is \"attachment:6/328eabcebf%2Focto+cat.png\"" do
      let(:link) { "attachment:6/328eabcebf%2Focto+cat.png" }

      it { should eq(["328eabcebf", "octo cat.png"]) }
    end

    context "when link is \"attachment:6/328eabcebf%2Focto%2Bcat.png\"" do
      let(:link) { "attachment:6/328eabcebf%2Focto%2Bcat.png" }

      it { should eq(["328eabcebf", "octo+cat.png"]) }
    end

    context "when link is \"attachment:1/2\"" do
      let(:link) { "attachment:1/2" }

      it { should eq(["2", "2"]) }
    end

    context "when link is \"attachment:1/1113\"" do
      let(:link) { "attachment:1/1113" }

      it { should eq(["89", "1113"]) }
    end
  end

  describe "#encoded_path" do
    subject(:encoded_path) { attachment.encoded_path }

    it { should eq(["328eabcebf", "octocat.png"]) }

    context "when link is \"attachment:6/328eabcebf/octo%5B%5Dcat.png\"" do
      let(:link) { "attachment:6/328eabcebf/octo%5B%5Dcat.png" }

      it { should eq(["328eabcebf", "octo%5B%5Dcat.png"]) }
    end

    context "when link is \"attachment:6/328eabcebf/octo%20cat.png\"" do
      let(:link) { "attachment:6/328eabcebf/octo%20cat.png" }

      it { should eq(["328eabcebf", "octo%20cat.png"]) }
    end

    context "when link is \"attachment:6/328eabcebf/FAILED_2018-11-07T09:47:36.311Test_2.Test[Test].xml\"" do
      let(:link) { "attachment:6/328eabcebf/FAILED_2018-11-07T09:47:36.311Test_2.Test[Test].xml" }

      it { should eq(["328eabcebf", "FAILED_2018-11-07T09%3A47%3A36.311Test_2.Test%5BTest%5D.xml"]) }
    end

    context "when link is \"attachment:1/2\"" do
      let(:link) { "attachment:1/2" }

      it { should eq(["2", "2"]) }
    end

    context "when link is \"attachment:1/1113\"" do
      let(:link) { "attachment:1/1113" }

      it { should eq(["89", "1113"]) }
    end
  end

  describe "#asset_name" do
    subject(:asset_name) { attachment.asset_name }

    it { should eq("octocat.png") }

    context "when link is \"attachment:6/328eabcebf/octocat.png\"" do
      let(:link) { "attachment:6/328eabcebf/octocat.png" }

      it { should eq("octocat.png") }
    end

    context "when link is \"attachment:1/2\"" do
      let(:link) { "attachment:1/2" }

      it { should eq("2") }
    end

    context "when link is \"attachment:1/1113\"" do
      let(:link) { "attachment:1/1113" }

      it { should eq("1113") }
    end
  end

  describe "#rewritten_link", :vcr do
    subject(:rewritten_link) { attachment.rewritten_link }

    it { should eq("https://example.com/projects/MIGR8/repos/hugo-pages/attachments/328eabcebf/octocat.png") }

    context "when link is \"attachment:6/328eabcebf/octo[]cat.png\"" do
      let(:link) { "attachment:6/328eabcebf/octo[]cat.png" }

      it { should eq("https://example.com/projects/MIGR8/repos/hugo-pages/attachments/328eabcebf/octo%5B%5Dcat.png") }
    end

    context "when link is \"attachment:1/2\"" do
      let(:link) { "attachment:1/2" }

      it { should eq("https://example.com/projects/MIGR8/repos/hugo-pages/attachments/2/2") }
    end

    context "when link is \"attachment:1/1113\"" do
      let(:link) { "attachment:1/1113" }

      it { should eq("https://example.com/projects/MIGR8/repos/hugo-pages/attachments/89/1113") }
    end
  end

  describe "#asset_content_type" do
    subject(:asset_content_type) { attachment.asset_content_type }

    it "calls content_type.content_type" do
      expect(attachment.content_type).to receive(:content_type)

      asset_content_type
    end
  end

  describe "#asset_url" do
    subject(:asset_url) { attachment.asset_url }

    it { should eq("tarball://root/attachments/131b93cdc85108ef1c75907eaf5bd5ae.png") }

    context "when link is \"attachment:1/2\"" do
      let(:link) { "attachment:1/2" }

      it { should eq("tarball://root/attachments/c9857ef5bb2d0e11edd304bc4c3409e5") }
    end

    context "when link is \"attachment:1/1113\"" do
      let(:link) { "attachment:1/1113" }

      it { should eq("tarball://root/attachments/4dcdbc66281ab56c85efdd8a7c6b8866") }
    end
  end

  describe "#archive!", :vcr do
    subject(:archive!) { attachment.archive! }

    it "fetches attachments for supported file types" do
      allow(current_export.archiver).to receive(:save_attachment)
      allow(repository_model).to receive(:attachment_content_type).with(["328eabcebf", "octocat.png"]).and_return("image/png")

      expect(repository_model).to receive(:attachment).with(["328eabcebf", "octocat.png"])

      archive!
    end

    it "saves attachments to the archive for supported file types" do
      file_double = double(:file_double)

      allow(repository_model).to receive(:attachment).with(["328eabcebf", "octocat.png"]).and_return(file_double)
      allow(repository_model).to receive(:attachment_content_type).with(["328eabcebf", "octocat.png"]).and_return("image/png")

      expect(current_export.archiver).to receive(:save_attachment).with(file_double, "131b93cdc85108ef1c75907eaf5bd5ae.png")

      archive!
    end

    it "does not fetch attachments for unsupported file types" do
      allow(repository_model).to receive(:attachment_content_type).with(["328eabcebf", "octocat.png"]).and_return("image/svg+xml")

      expect(repository_model).to_not receive(:attachment)

      archive!
    end

    it "does not save attachments to the archive for unsupported file types" do
      allow(repository_model).to receive(:attachment_content_type).with(["328eabcebf", "octocat.png"]).and_return("image/svg+xml")

      expect(current_export.archiver).to_not receive(:save_attachment)

      archive!
    end

    it "returns false for unsupported file types" do
      allow(repository_model).to receive(:attachment_content_type).with(["328eabcebf", "octocat.png"]).and_return("image/svg+xml")

      should eq(false)
    end

    it "calls #log_with_url when encountering an unsupported file type" do
      allow(repository_model).to receive(:attachment_content_type).with(["328eabcebf", "octocat.png"]).and_return("image/svg+xml")

      expect(attachment).to receive(:log_with_url)

      archive!
    end

    # This test was recorded against our https://test-bbs-o.githubapp.com instance
    # and the PR https://test-bbs-o.githubapp.com/projects/MEC/repos/test-attachments/pull-requests/1/overview
    context "when parent_type and parent_model are provided" do
      let(:project_model) { bitbucket_server.project_model("MEC") }
      let(:repository_model) { project_model.repository_model("test-attachments") }
      let(:pull_request_model) { repository_model.pull_request_model(pull_request_id) }
      let(:pull_request_id) { 1 }
      let(:repository) { repository_model.repository }
      let(:pull_request) { pull_request_model.pull_request }

      let(:bbs_model) do
        {
          repository: repository,
          path: ["328eabcebf", "octocat.png"]
        }
      end

      let(:parent_type) { "pull_request" }
      let(:parent_model) do
        {
          repository: repository,
          pull_request: pull_request,
          description: pull_request["description"]
        }
      end

      let(:attachment) do
        described_class.new(
          link: link,
          tooltip: tooltip,
          repository_model: repository_model,
          archiver: current_export.archiver,
          parent_type: parent_type,
          parent_model: parent_model
        )
      end

      it "calls #log_with_url when faraday exception is raised" do
        allow(repository_model).to receive(:attachment_content_type).and_raise(Faraday::BadRequestError.new("error"))

        expect(attachment).to receive(:log_with_url).with(
          severity:   :warn,
          message:    "was skipped because the content type `unknown` is not supported or unable to fetch attachment.",
          model:      bbs_model,
          model_name: "attachment",
          console:    true,
          parent_type: parent_type,
          parent_model: parent_model
        )

        archive!
      end

    end
  end

  describe "#markdown_link", :vcr do
    let(:content_type) { "image/png" }
    subject(:markdown_link) { attachment.markdown_link }

    before(:each) { expect(repository_model).to receive(:attachment_content_type).with(["328eabcebf", "octocat.png"]).and_return(content_type) }

    it { should eq("(https://example.com/projects/MIGR8/repos/hugo-pages/attachments/328eabcebf/octocat.png 'octocat')") }

    context "when attachment content type is \"image/svg+xml\"" do
      let(:content_type) { "image/svg+xml" }

      it { should eq("(attachment:6/328eabcebf%2Foctocat.png 'octocat')") }
    end
  end
end
