# frozen_string_literal: true
class BbsExporter
  class PullRequestExporter
    include Writable
    include SafeExecution
    include TimeHelpers
    include PullRequestHelpers

    REVIEW_BLANK_COMMIT_SHA = "1111111111111111111111111111111111111111".freeze

    log_handled_exceptions_to :logger

    attr_reader :pull_request, :repository_exporter, :pull_request_model

    delegate :archiver, to: :current_export
    delegate :repository_model, :pull_request, to: :pull_request_model
    delegate :repository, to: :repository_model
    delegate :current_export, to: :repository_exporter
    delegate :bitbucket_server, :logger, to: :current_export

    def initialize(pull_request_model:, repository_exporter:, order: nil)
      @pull_request_model = pull_request_model
      @repository_exporter = repository_exporter
      @order = order
    end

    # Alias for `pull_request`
    #
    # @return [Hash]
    def model
      pull_request
    end

    def created_date
      pull_request["createdDate"]
    end

    def author
      pull_request["author"]["user"]
    end

    def description
      pull_request["description"].to_s
    end

    def attachment_exporter
      @attachment_exporter ||= AttachmentExporter.new(
        current_export:   current_export,
        repository_model: repository_model,
        parent_type:      "pull_request",
        parent_model:     bbs_model,
        user:             author,
        body:             description,
        created_date:     created_date,
        order:            @order
      )
    end

    def bbs_model
      @bbs_model ||= {
        repository:   repository,
        pull_request: pull_request,
        description:  description
      }
    end

    # Instruct the exporter to export the `pull_request`. Also extracts any
    # inline attachments from the `pull_request`'s body content.
    #
    # @return [Boolean] whether or not the pull_request successfully exported
    def export
      return warn_pull_request_no_diff if pull_request_model.commits.empty?

      serialize("user", author, @order) if author

      attachment_exporter.export
      bbs_model[:description] = attachment_exporter.rewritten_body
      bbs_model[:merge_commit_sha] = merge_commit_sha

      serialize("pull_request", bbs_model, @order)

      if open? && from_fork?
        archiver.create_branch(
          repository: repository,
          name: model["fromRef"]["displayId"],
          target: model["fromRef"]["latestCommit"]
        )
      end

      export_pull_request_comments
      export_pull_request_review_groups
      export_pull_request_review_comments
      export_pull_request_file_comments
      export_pull_request_reviews
      export_issue_events

      true
    rescue StandardError => e
      current_export.logger.error <<~EOF
        Error while exporting Pull Request (#{e.message}):
        #{pull_request.inspect}
        #{e.backtrace.join("\n")}
      EOF

      current_export.output_logger.error(
        "Unable to export Pull Request #{pull_request["id"]} from repository " +
        model_url_service.url_for_model(repository)
      )

      false
    end

    def warn_pull_request_no_diff
      log_with_url(
        severity:   :warn,
        message:    "was skipped because the PR has no diff",
        model:      bbs_model,
        model_name: "pull_request",
        console:    true
      )
    end

    def merge_commit_sha
      return unless pull_request_model.activities

      pull_request_model.activities.detect do |activity|
        next unless activity["commit"]
        return activity["commit"]["id"] if activity["action"] == "MERGED"
      end
    end

    def comment_activities
      pull_request_model.activities.select { |a| comment?(a) }
    end

    # Get PR activities for diff comments (excluding file comments).
    #
    # @return [Array<Hash>] Pull request activities for diff comments
    #   (excluding file comments).
    def diff_comment_activities
      pull_request_model.activities.select do |activity|
        diff_comment?(activity)
      end
    end

    def file_comment_activities
      pull_request_model.activities.select do |activity|
        file_comment?(activity)
      end
    end

    # Get PR activities for issue events.
    #
    # @return [Array<Hash>] Pull request activities for issue events.
    def issue_event_activities
      pull_request_model.activities.select { |a| issue_event?(a) }
    end

    # Get the first PR activity for diff comments grouped by user slug and
    # commit ID.
    #
    # @return [Array] Commit ID and first PR activity.
    def grouped_diff_comment_activities
      grouped_activities = diff_comment_activities.group_by do |activity|
        user_slug = activity.dig("user", "slug")
        commit_id = commit_id_from_activity(activity)

        [user_slug, commit_id]
      end

      grouped_activities.map do |user_slug_commit_id, activities|
        user_slug, commit_id = user_slug_commit_id
        first_activity = activities.min { |a| a["createdDate"] }

        [commit_id, first_activity]
      end
    end

    def review_activities
      pull_request_model.activities.select { |a| reviewed?(a) }
    end

    # Returns a hash of commit sha1s sorted by timestamp
    #
    # @return [Hash{Integer => String}]
    def timestamped_commit_ids
      @timestamped_commit_ids ||= begin
        timestamped_commits = pull_request_model.commits.map do |commit|
          [commit["authorTimestamp"], commit["id"]]
        end
        sorted_desc_timestamped_commits = timestamped_commits.sort.reverse
        sorted_desc_timestamped_commits.to_h
      end
    end

    # Searches #timestamped_commit_ids for a timestamp that immediately precedes the
    # provided activity_timestamp and returns the associated commit sha1
    #
    # @param [Integer] activity_timestamp the timestamp to search by
    #
    # @return [String] the returned sha1 or REVIEW_BLANK_COMMIT_SHA if none is found
    def commit_id_for_timestamp(activity_timestamp)
      commit = timestamped_commit_ids.detect do |timestamp, commit_id|
        activity_timestamp >= timestamp
      end&.last
      return commit || REVIEW_BLANK_COMMIT_SHA
    end

    # Export pull request comments.
    def export_pull_request_comments
      comment_activities.each do |comment_activity|
        PullRequestCommentExporter.new(
          pull_request_comment: comment_activity["comment"],
          pull_request:         pull_request,
          repository_exporter:  repository_exporter,
          order:                @order
        ).export
      end
    end

    # Export pull request review groups for review comments.
    def export_pull_request_review_groups
      grouped_diff_comment_activities.each do |commit_id, activity|
        PullRequestReviewExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          commit_id:           commit_id,
          activity:            activity,
          order:               @order
        ).export
      end
    end

    # Export pull request review comments.
    def export_pull_request_review_comments
      diff_comment_activities.each do |activity|
        PullRequestReviewCommentExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          activity:            activity,
          order:               @order
        ).export
      end
    end

    # Export pull request file comments.
    def export_pull_request_file_comments
      file_comment_activities.each do |activity|
        PullRequestCommentExporter.new(
          pull_request_comment: activity["comment"],
          pull_request:         pull_request,
          repository_exporter:  repository_exporter,
          order:                @order,
          formatted_text:       comment_body_for_review_file_comment(activity)
        ).export
      end
    end

    # Export pull request reviews.
    def export_pull_request_reviews
      review_activities.each do |activity|
        commit_id = commit_id_for_timestamp(activity["createdDate"])

        PullRequestReviewExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          commit_id:           commit_id,
          activity:            activity,
          order:               @order
        ).export
      end
    end

    # Export issue events.
    def export_issue_events
      issue_event_activities.each do |activity|
        IssueEventExporter.new(
          repository_exporter: repository_exporter,
          pull_request_model:  pull_request_model,
          activity:            activity,
          order:               @order
        ).export
      end
    end

    private

    def open?
      model["open"]
    end

    def from_fork?
      model["fromRef"]["repository"]["id"] != model["toRef"]["repository"]["id"]
    end
  end
end
