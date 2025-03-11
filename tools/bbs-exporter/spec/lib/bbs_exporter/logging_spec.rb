# frozen_string_literal: true

require "spec_helper"

class TestError < StandardError; end

describe BbsExporter do
  let(:user) do
    bitbucket_server.user
  end

  describe "#log_with_url", :vcr do
    it "writes to the log" do
      expect(current_export.logger).to receive(:add).with(
        2,
        "user: https://example.com/users/unit-test message"
      )

      current_export.log_with_url(
        severity:   :warn,
        message:    "message",
        model:      user,
        model_name: "user"
      )
    end

    it "writes to the log and console when console is true" do
      expect(current_export.logger).to receive(:add).with(
        2,
        "user: https://example.com/users/unit-test message"
      )

      expect(current_export.output_logger).to receive(:add).with(
        2,
        "user: https://example.com/users/unit-test message"
      )

      current_export.log_with_url(
        severity:   :warn,
        message:    "message",
        model:      user,
        model_name: "user",
        console:    true
      )
    end

    it "writes to the log but not the console when console is nil" do
      expect(current_export.logger).to receive(:add).with(
        2,
        "user: https://example.com/users/unit-test message"
      )

      expect(current_export.output_logger).to_not receive(:add)

      current_export.log_with_url(
        severity:   :warn,
        message:    "message",
        model:      user,
        model_name: "user"
      )
    end

    it "passes model and model_name to ModelUrlService" do
      expect(current_export.model_url_service).to receive(
        :url_for_model
      ).with(user, type: "user")

      current_export.log_with_url(
        severity:   :warn,
        message:    "message",
        model:      user,
        model_name: "user"
      )
    end

    # This test was recorded against our https://test-bbs-o.githubapp.com instance
    # and the PR https://test-bbs-o.githubapp.com/projects/MEC/repos/test-attachments/pull-requests/1/overview
    context "with parent type and parent model" do
      let(:project_model) { bitbucket_server.project_model("MEC") }
      let(:repository_model) { project_model.repository_model("test-attachments") }
      let(:pull_request_model) { repository_model.pull_request_model(pull_request_id) }
      let(:pull_request_id) { 1 }
      let(:repository) { repository_model.repository }
      let(:pull_request) { pull_request_model.pull_request }

      let(:bbs_model) do
        {
          repository: repository,
          pull_request: pull_request,
          description: pull_request["description"]
        }
      end

      let(:parent_type) { "repository" }
      let(:parent_model) { bbs_model }

      it "logs parent type and parent model url if included" do
        expect(current_export.logger).to receive(:add).with(
          2,
          "pull_request: https://example.com/projects/MEC/repos/test-attachments/pull-requests/1 message (Tied to repository: https://example.com/projects/MEC/repos/test-attachments)"
        )

        expect(current_export.output_logger).to_not receive(:add)

        current_export.log_with_url(
          severity:   :warn,
          message:    "message",
          model:      bbs_model,
          model_name: "pull_request",
          parent_type: parent_type,
          parent_model: parent_model
        )
      end
    end
  end

  describe "#progress_bar_title" do
    it "sets the title before and after the block is called" do
      test_double = double("TestDouble")
      progress_bar_io = current_export.send(:progress_bar_io)

      expect(progress_bar_io).to receive(:title=).with("title").ordered
      expect(test_double).to receive(:test).ordered
      expect(progress_bar_io).to receive(:title=).with("").ordered

      current_export.progress_bar_title("title") do
        test_double.test
      end
    end

    it "returns the value returned from the block" do
      returned_value = current_export.progress_bar_title("title") do
        :expected_value
      end

      expect(returned_value).to eq(:expected_value)
    end
  end

  describe "#log_exception" do
    subject(:_log_exception) do
      begin
        raise exception
      rescue TestError => e
        current_export.log_exception(e)
      end
    end

    let(:exception) { TestError.new(exception_message) }
    let(:exception_message) { "I am error" }

    it "logs a simple exception to the output" do
      expect(@_spec_output_logger).to receive(:error).with("I am error")
      subject
    end

    it "logs to the file logger with the exception message" do
      expect(@_spec_logger).to receive(:error).with(include("I am error"))
      subject
    end

    it "logs to the file logger with a backtrace" do
      expect(@_spec_logger).to receive(:error).with(include(__FILE__))
      subject
    end

    context "with a custom message" do
      subject(:_log_exception) do
        begin
          raise exception
        rescue TestError => e
          current_export.log_exception(e, message: "Hello world")
        end
      end

      it "logs the custom message to the output" do
        expect(@_spec_output_logger).to receive(:error).with("Hello world: I am error")
        subject
      end

      it "logs the custom message to the file logger" do
        expect(@_spec_logger).to receive(:error).with(include("message:\nHello world"))
        subject
      end
    end

    context "with custom meta" do
      subject(:_log_exception) do
        begin
          raise exception
        rescue TestError => e
          current_export.log_exception(e, darth: ["Maul", "Vader"])
        end
      end

      it "logs the custom meta to the file logger" do
        expect(@_spec_logger).to receive(:error).with(include(%(darth:\n["Maul", "Vader"])))
        subject
      end
    end
  end
end
