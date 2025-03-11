# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::PullRequestReviewCommentExporter, :vcr do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(6)
  end

  let(:pull_request_model_merge_conflict) do
    repository_model.pull_request_model(11)
  end

  let(:repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model: repository_model,
      current_export:   current_export
    )
  end

  let(:activities) do
    pull_request_model.activities
  end

  let(:activities_merge_conflict) do
    pull_request_model_merge_conflict.activities
  end

  let(:activity) do
    comment_activity_start_with(activities, "Comment on line 3.")
  end

  let(:pr_review_comment_exporter) do
    BbsExporter::PullRequestReviewCommentExporter.new(
      repository_exporter: repository_exporter,
      pull_request_model:  pull_request_model,
      activity:            activity
    )
  end

  let(:pr_review_comment_exporter_merge_conflict) do
    BbsExporter::PullRequestReviewCommentExporter.new(
      repository_exporter: repository_exporter,
      pull_request_model:  pull_request_model_merge_conflict,
      activity:            activity
    )
  end

  describe "#diff", :pull_request_helpers do
    subject(:activity) do
      comment_activity_start_with(activities, "Comment on newline.")
    end

    it "should call the model's #diff with a full path" do
      expect(pull_request_model).to receive(:diff).with(
        "app/views/layouts/application.html.erb",
        src_path:  nil,
        diff_type: "COMMIT",
        since_id:  "99ece937f497284e663b81fc1ad6ff9fcddd8a7c",
        until_id:  "ace0ddae7cc4f2967e9cefafdafb1aa5c65f3ea0"
      )

      pr_review_comment_exporter.send(:diff)
    end
  end

  describe "#binary_file?", :pull_request_helpers do
    context "for file comments on a non-binary file" do
      subject(:activity) do
        comment_activity_start_with(activities, "File comment.")
      end

      it "should be falsey" do
        expect(pr_review_comment_exporter.binary_file?).to be_falsey
      end
    end

    context "for file comments on a binary file" do
      subject(:activity) do
        comment_activity_start_with(activities, "File comment on binary file.")
      end

      it "should return true" do
        expect(pr_review_comment_exporter.binary_file?).to be(true)
      end
    end

    context "for diff comments" do
      subject(:activity) do
        comment_activity_start_with(activities, "Comment on line 3.")
      end

      it "should be falsey" do
        expect(pr_review_comment_exporter.binary_file?).to be_falsey
      end
    end
  end

  describe "#export", :pull_request_helpers do
    subject(:_export) { pr_review_comment_exporter.export }
    let(:activity) do
      comment_activity_start_with(activities, "Comment on line 3.")
    end

    it { is_expected.to be_truthy }

    context "for diff comments outside of GitHub context" do
      let(:activity) do
        comment_activity_start_with(activities, "Comment on line 1.")
      end

      it "should call comment_body_with_original_line" do
        expect(pr_review_comment_exporter).to receive(
          :comment_body_with_original_line
        ).and_call_original

        pr_review_comment_exporter.export
      end

      it "should serialize data" do
        expect(pr_review_comment_exporter).to receive(:serialize).ordered
        expect(pr_review_comment_exporter).to receive(:serialize).with(
          "user", activity["user"], nil
        ).ordered
        pr_review_comment_exporter.export
      end
    end

    context "for diff comments inside of GitHub context" do
      let(:activity) do
        comment_activity_start_with(activities, "Comment on line 3.")
      end

      it "should not call comment_body_with_line_number" do
        expect(pr_review_comment_exporter).to_not receive(
          :comment_body_with_line_number
        )

        pr_review_comment_exporter.export
      end
    end


    context "with an invalid review comment" do
      before { activity["comment"].delete("author") }

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        expect(pr_review_comment_exporter).to receive(:log_exception).with(
          be_a(ActiveModel::ValidationError),
          message: "Unable to export review comment, see logs for details",
          url: "https://example.com/projects/MIGR8/repos/hugo-pages/pull-requests/6/overview?commentId=49#r49",
          model: include(commit_id: "112e299ef8f06f951dde8ce105aad0252180cde0")
        )

        subject
      end
    end

    context "with an activity with an unreachable commit" do
      before { activity["commentAnchor"]["toHash"] = "invalidcommit123456789" }

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        subject
        expect(@_spec_output_log.string).to include("Unable to export review comment, see logs for details")
      end
    end

    context "when #diff returns nil" do
      before(:each) do
        allow(pr_review_comment_exporter).to receive(:diff)
      end

      it { is_expected.to be_falsey }

      it "logs the validation exception" do
        subject
        expect(@_spec_output_log.string).to include("Unable to export review comment, see logs for details")
      end

      it "should not serialize data" do
        pr_review_comment_exporter.export

        url = current_export.model_url_service.url_for_model(
          pr_review_comment_exporter.bbs_model,
          type: "pull_request_review_comment"
        )

        seen = ExtractedResource.exists?(model_type: "pull_request_review_comment", model_url: url)

        expect(seen).to be(false)
      end
    end
  end

  describe "#moved?", :pull_request_helpers do
    context "when #diff returns nil" do
      it "should be falsey" do
        allow(pr_review_comment_exporter).to receive(:diff)

        expect(pr_review_comment_exporter.moved?).to be_falsey
      end
    end
  end

  describe "#position", :pull_request_helpers do
    context "when #diff returns nil" do
      it "should return nil" do
        allow(pr_review_comment_exporter).to receive(:diff)

        expect(pr_review_comment_exporter.position).to be_nil
      end
    end
  end

  describe "#comment_body_with_original_line", :pull_request_helpers do
    context "for a given activity" do
      subject(:activity) do
        comment_activity_start_with(activities, "Comment on line 1.")
      end

      it "includes the original comment body" do
        body = pr_review_comment_exporter.comment_body_with_original_line(
          activity["commentAnchor"]["line"],
          activity["comment"]["text"]
        )
        original_body = activity["comment"]["text"]

        expect(body.end_with?(original_body)).to eq(true)
      end
    end
  end

  describe "#attachment_exporter", :pull_request_helpers do
    let (:activity) do
      comment_activity_start_with(activities, "Comment on line 1.")
    end

    subject(:attachment_exporter) do
      pr_review_comment_exporter.attachment_exporter
    end

    it "sets current_export to the correct value" do
      expect(attachment_exporter.current_export).to eq(
        pr_review_comment_exporter.current_export
      )
    end

    it "sets repository_model to the correct value" do
      expect(attachment_exporter.repository_model).to eq(
        pr_review_comment_exporter.repository_model
      )
    end

    it "sets parent_type to the correct value" do
      expect(attachment_exporter.parent_type).to eq(
        "pull_request_review_comment"
      )
    end

    it "sets parent_model to the correct value" do
      expect(attachment_exporter.parent_model).to eq(
        pr_review_comment_exporter.bbs_model
      )
    end

    it "sets attachment_exporter to the correct value" do
      expect(attachment_exporter.user).to eq(
        pr_review_comment_exporter.author
      )
    end

    it "sets body to the correct value" do
      expect(attachment_exporter.body).to eq(
        pr_review_comment_exporter.text
      )
    end

    it "sets created_date to the correct value" do
      expect(attachment_exporter.created_date).to eq(
        pr_review_comment_exporter.created_date
      )
    end
  end
end
