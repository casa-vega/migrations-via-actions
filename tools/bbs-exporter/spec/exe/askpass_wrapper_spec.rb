# frozen_string_literal: true

require "spec_helper"

describe "exe/askpass-wrapper" do
  let(:askpass_wrapper_path) { Bundler.root.join("exe", "bbs-exporter-askpass").to_s }

  describe "script contents" do
    subject(:askpass_wrapper_contents) { File.read(askpass_wrapper_path) }

    it { should start_with("#!/bin/sh\n") }
  end

  describe "stdout" do
    let(:password) { "password" }
    let(:token) { nil }

    let(:env_vars) do
      {
        "BITBUCKET_SERVER_API_PASSWORD" => password,
        "BITBUCKET_SERVER_API_TOKEN" => token
      }
    end

    subject(:askpass_wrapper_stdout) do
      Open3.popen3(env_vars, askpass_wrapper_path) do |stdin, stdout, stderr|
        stdout.read
      end
    end

    it { should eq("password") }

    context "when token is present" do
      let(:token) { "token" }

      it { should eq("token") }
    end
  end
end
