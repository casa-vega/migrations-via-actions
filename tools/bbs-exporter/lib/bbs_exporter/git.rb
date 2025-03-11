# frozen_string_literal: true

class BbsExporter
  class Git
    include Logging

    ASKPASS_WRAPPER_PATH = Bundler.root.join("exe", "bbs-exporter-askpass").to_s
    BRANCH_OBJECT_ERROR_REGEXP = /^output:.*with nonexistent object.*\\n/.freeze

    attr_accessor :ssl_verify

    def initialize(ssl_verify: true)
      @ssl_verify = ssl_verify
    end

    # Create a copy of a repository for archiving.
    #
    # @param url [String] URL for cloning a repository.
    # @param target [String] Local directory to clone repository to.
    def clone(url:, target:)
      # Kill the last attempt to export.
      FileUtils.rm_rf(target)

      # Start with a normal git clone, so that we get objects stored in a
      # network repo, if it exists.
      progress_bar_title("git clone #{url}") do
        ClimateControl.modify(env) do
          ::Git.clone(url, target, mirror: true)
        end
      end
    end

    def create_branch(path:, name:, target:)
      git_base = ::Git.bare(path)

      return if git_base.is_branch?(name)

      git_base.update_ref(name, target)
    rescue ::Git::FailedError => error
      raise unless BRANCH_OBJECT_ERROR_REGEXP.match?(error.message)
    end

    private

    def env
      {
        GIT_ASKPASS: ASKPASS_WRAPPER_PATH,
        GIT_SSL_NO_VERIFY: (!ssl_verify).to_s
      }
    end
  end
end
