# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::Git do
  let(:askpass_wrapper_path) { Bundler.root.join("exe", "bbs-exporter-askpass").to_s }
  let(:ssl_verify) { true }
  let(:git) { described_class.new(ssl_verify: ssl_verify) }

  describe "#clone" do
    subject(:clone) { git.clone(url: nil, target: nil) }

    before(:each) do
      allow(FileUtils).to receive(:rm_rf)
      git.progress_bar_disable!
    end

    it "passes GIT_ASKPASS environment variable to ::Git" do
      expect(::Git).to receive(:clone) do
        expect(ENV["GIT_ASKPASS"]).to eq(askpass_wrapper_path)
      end

      clone
    end

    it "passes GIT_SSL_NO_VERIFY=false to ::Git" do
      expect(::Git).to receive(:clone) do
        expect(ENV["GIT_SSL_NO_VERIFY"]).to eq("false")
      end

      clone
    end

    context "when ssl_verify is not passed to BbsExporter::Git.new" do
      let(:git) { described_class.new }

      it "passes GIT_SSL_NO_VERIFY=false to ::Git by default" do
        expect(::Git).to receive(:clone) do
          expect(ENV["GIT_SSL_NO_VERIFY"]).to eq("false")
        end

        clone
      end
    end

    context "when #ssl_verify is false" do
      let(:ssl_verify) { false }

      it "passes GIT_SSL_NO_VERIFY=true to ::Git" do
        expect(::Git).to receive(:clone) do
          expect(ENV["GIT_SSL_NO_VERIFY"]).to eq("true")
        end

        clone
      end
    end
  end

  describe "#create_branch" do
    let(:git_base_double) { instance_double(::Git::Base) }
    let(:is_branch) { false }

    let(:path) { File::NULL }
    let(:name) { "example-branch" }
    let(:target) { "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }

    let(:git_cmd) { "git '--git-dir=#{path}' '-c' 'core.quotePath=true' '-c' 'color.ui=false' 'update-ref' 'refs/heads/#{name}' '#{target}'  2>&1" }
    let(:status) { "pid 90302 exit 128" }
    let(:stdout) { "fatal: update_ref failed for ref 'refs/heads/#{name}': cannot update ref 'refs/heads/#{name}': trying to write ref 'refs/heads/#{name}' with nonexistent object #{target}\\n" }

    let(:result_error) { OpenStruct.new(git_cmd: git_cmd, status: status, stdout: stdout) }

    let(:git_failed_error) { ::Git::FailedError.new(result_error) }

    subject(:create_branch) do
      git.create_branch(
        path: path,
        name: name,
        target: target
      )
    end

    before(:each) do
      allow(::Git).to receive(:bare).with(path).and_return(git_base_double)

      allow(git_base_double).to receive(:is_branch?).with(name).and_return(is_branch)
      allow(git_base_double).to receive(:update_ref)
    end

    it "calls Git::Base#update_ref" do
      expect(git_base_double).to receive(:update_ref).with(name, target)

      create_branch
    end

    context "when branch already exists" do
      let(:is_branch) { true }

      it "does not call Git::Base#update_ref" do
        expect(git_base_double).to_not receive(:update_ref)

        create_branch
      end
    end

    context "with a target that doesn't exist" do
      before(:each) { expect(git_base_double).to receive(:update_ref).with(name, target).and_raise(git_failed_error) }

      it { expect { create_branch }.to_not raise_error }
    end

    context "when an unexpected error is raised" do
      let(:stdout) { "unexpected error" }

      before(:each) { expect(git_base_double).to receive(:update_ref).with(name, target).and_raise(git_failed_error) }

      it { expect { create_branch }.to raise_error(git_failed_error) }
    end
  end
end
