# frozen_string_literal: true

class BbsExporter
  # Persists all the data for an export.
  class ArchiveBuilder
    attr_reader :current_export

    delegate :options, to: :current_export

    EXTRACTED_RESOURCES = [
      "user",
      "team",
      "organization",
      "repository",
      "issue_comment",
      "issue_event",
      "pull_request",
      "pull_request_review",
      "pull_request_review_comment",
      "commit_comment",
      "release",
      "protected_branch",
      "attachment"
    ]

    def initialize(current_export:)
      @current_export = current_export
    end

    # Clone a repository's Git repository to the staging dir
    def clone_repo(repository)
      git.clone(
        url:    repo_clone_url(repository),
        target: repo_path(repository)
      )
    end

    def create_branch(repository:, name:, target:)
      git.create_branch(
        path: repo_path(repository),
        name: name,
        target: target
      )
    end

    # Put all of the data into a tar file and dispose of temporary files.
    def create_tar(path)
      write_json_file("urls.json", UrlTemplates.new.templates)
      write_json_file("schema.json", {version: "1.2.0"})
      FileUtils.remove_entry_secure File.join(staging_dir, "db.sql")
      Archiver.pack(File.expand_path(path), staging_dir)
      FileUtils.remove_entry_secure staging_dir
    end

    # Returns true if anything was written to the archive.
    def used?
      ExtractedResource.any?
    end

    # Write a hash to a JSON file
    #
    # @param [String] path the path to the file to be written
    # @param [Hash] contents the Hash to be converted to JSON and written to
    #   file
    def write_json_file(path, contents)
      File.open(File.join(staging_dir, path), "w") do |file|
        file.write(JSON.pretty_generate(contents))
      end
    end

    # Writes all ExtractedResources to JSON files
    def write_files
      @current_export.output_logger.info "Creating archive manifests..."

      # for each type of exported resource, grab 100 at a time and throw in json blob
      EXTRACTED_RESOURCES.each do |extracted_resource|
        serialized_model_writer = SerializedModelWriter.new(staging_dir, extracted_resource)

        exported_count = serialized_model_writer.write_models

        @current_export.output_logger.info "#{extracted_resource.pluralize.titleize} exported: #{exported_count}" unless exported_count.zero?
      end
    end

    # The path where repositories are written to disk
    #
    # @param [Hash] repository the repository that will be written to disk
    # @return [String] the path where this repository's git repository will be written
    #   to disk
    def repo_path(repository)
      "#{staging_dir}/repositories/#{repository["project"]["key"] + "/" + repository["slug"]}.git"
    end

    def save_attachment(attachment_data, *path)
      target = File.join(staging_dir, "attachments", *path)
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, attachment_data, mode: "wb")
    end

    def staging_dir
      current_export.staging_dir
    end

    private

    def git
      @git ||= Git.new(ssl_verify: options[:ssl_verify])
    end

    def bitbucket_server
      current_export.bitbucket_server
    end

    def repo_clone_url(repository, user: bitbucket_server.authenticated_user)
      link = repository["links"]["clone"].detect do |clone_link|
        break clone_link["href"] if clone_link["name"] == "http"
      end

      return unless link

      uri = Addressable::URI.parse(link)
      uri.user = CGI.escape(user)

      uri.to_s
    end
  end
end
