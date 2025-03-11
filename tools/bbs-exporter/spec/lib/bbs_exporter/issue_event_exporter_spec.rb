# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::IssueEventExporter, :vcr do
  let(:project_model) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository_model) do
    project_model.repository_model("hugo-pages")
  end

  let(:pull_request_model) do
    repository_model.pull_request_model(1)
  end

  let(:project) do
    project_model.project
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

  let(:repository_exporter) do
    BbsExporter::RepositoryExporter.new(
      repository_model: repository_model,
      current_export:   current_export
    )
  end

  let(:issue_event_exporter) do
    BbsExporter::IssueEventExporter.new(
      repository_exporter: repository_exporter,
      pull_request_model:  pull_request_model,
      activity:            activity
    )
  end

  describe "#export" do
    context "for DECLINED actions" do
      subject(:activity) do
        activities.detect { |a| a["action"] == "DECLINED" }
      end

      it "should export a closed issue event" do
        expect(issue_event_exporter).to receive(:serialize).with(
          "issue_event", hash_including(event: "closed"), nil
        )

        issue_event_exporter.export
      end
    end

    context "for REOPENED actions" do
      subject(:activity) do
        activities.detect { |a| a["action"] == "REOPENED" }
      end

      it "should export a closed issue event" do
        expect(issue_event_exporter).to receive(:serialize).with(
          "issue_event", hash_including(event: "reopened"), nil
        )

        issue_event_exporter.export
      end
    end
  end
end
