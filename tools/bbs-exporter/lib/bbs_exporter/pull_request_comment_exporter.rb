# frozen_string_literal: true

class BbsExporter
  class PullRequestCommentExporter
    include Logging
    include Writable

    attr_reader :archiver, :pull_request, :pull_request_comment,
      :repository_exporter

    delegate :repository, :repository_model, :current_export,
      to: :repository_exporter

    def initialize(pull_request:, pull_request_comment:, repository_exporter:, order: nil, formatted_text: nil)
      @pull_request = pull_request
      @pull_request_comment = pull_request_comment
      @repository_exporter = repository_exporter
      @archiver = current_export.archiver
      @order = order
      @formatted_text = formatted_text

      serialize("user", author, @order) if author
    end

    def author
      pull_request_comment["author"]
    end

    def text
      @formatted_text  || pull_request_comment["text"]
    end

    def created_date
      pull_request_comment["createdDate"]
    end

    # References the BitbucketServer instance
    #
    # @return [BitbucketServer]
    def bitbucket_server
      current_export.bitbucket_server
    end

    def bbs_model
      {
        pull_request:         pull_request,
        pull_request_comment: pull_request_comment.merge({"text" => text})
      }
    end

    # Instruct the exporter to export the `pull_request_comment`
    # @return [Boolean] whether or not the comment successfully exported
    def export
      attachment_exporter.export
      text.replace(attachment_exporter.rewritten_body)

      begin
        serialize("issue_comment", bbs_model, @order)
        export_pull_request_comment_reply_comments

        true
      rescue ActiveModel::ValidationError => e
        log_exception(e,
          message: "Unable to export comment, see logs for details",
          url: model_url_service.url_for_model(bbs_model, type: "issue_comment"),
          model: bbs_model
        )
        false
      end
    end

    def attachment_exporter
      @attachment_exporter ||= AttachmentExporter.new(
        current_export:   current_export,
        repository_model: repository_model,
        parent_type:      "issue_comment",
        parent_model:     bbs_model,
        user:             author,
        body:             text,
        created_date:     created_date,
        order:            @order
      )
    end

    # Serialize and export the comments for a given Bitbucket Server Pull
    # Request as GitHub Comments immediately.
    #
    # @return
    def export_pull_request_comment_reply_comments
      pull_request_comment["comments"].each do |child_pull_request_comment|
        PullRequestCommentExporter.new(
          pull_request_comment: child_pull_request_comment,
          pull_request:         pull_request,
          repository_exporter:  repository_exporter,
          order:                @order
        ).export
      end
    end

    private

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end
  end
end
