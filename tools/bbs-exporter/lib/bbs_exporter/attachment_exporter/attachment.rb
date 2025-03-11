# frozen_string_literal: true

class BbsExporter
  class AttachmentExporter
    class Attachment
      INDEXED_PATH_REGEXP = %r{\Aattachment:(?<repo_id>\d+)/(?<attachment_id>\d+)\z}.freeze

      attr_accessor :link, :tooltip, :repository_model, :archiver, :parent_type, :parent_model

      delegate :repository, to: :repository_model
      delegate :current_export, to: :archiver
      delegate :log_with_url, to: :current_export

      def initialize(link:, tooltip: nil, repository_model:, archiver:, parent_type: nil, parent_model: nil)
        @link = link
        @tooltip = tooltip
        @repository_model = repository_model
        @archiver = archiver
        @parent_type = parent_type
        @parent_model = parent_model
      end

      def content_type
        @content_type ||= ContentType.new(
          repository_model: repository_model,
          path:             path
        )
      end

      def asset_content_type
        content_type.content_type
      end

      def repository_id
        repository["id"].to_s
      end

      def filename
        @filename ||= Digest::MD5.hexdigest(link) + File.extname(link)
      end

      def path
        return @path if @path

        @path = indexed_attachment? ? indexed_path : hashed_path
      end

      def encoded_path
        @encoded_path ||= path.map { |p| ERB::Util.url_encode(p) }
      end

      def asset_name
        path.last
      end

      def model_url_service
        @model_url_service ||= ModelUrlService.new
      end

      def rewritten_link
        model_url_service.url_for_model(bbs_model, type: "attachment")
      end

      def asset_url
        uri_path = File.join("attachments", filename)

        uri = Addressable::URI.new(
          scheme: "tarball",
          host:   "root",
          path:   uri_path
        )

        uri.normalize.to_s
      end

      def archive!
        if content_type.supported?
          attachment_data = repository_model.attachment(path)
          archiver.save_attachment(attachment_data, filename)
        else
          log_with_url(
            severity:   :warn,
            message:    "was skipped because the content type `#{asset_content_type}` is not supported or unable to fetch attachment.",
            model:      bbs_model,
            model_name: "attachment",
            console:    true,
            parent_type: parent_type,
            parent_model: parent_model
          )
          false
        end
      end

      def markdown_link
        return original_markdown_link unless content_type.supported?
        rewritten_markdown_link
      end

      def rewritten_markdown_link
        "(#{rewritten_link}#{tooltip})"
      end

      def original_markdown_link
        "(#{link}#{tooltip})"
      end

      def bbs_model
        {
          repository: repository,
          path:       encoded_path
        }
      end

      private

      def indexed_attachment?
        INDEXED_PATH_REGEXP.match?(link)
      end

      def hashed_path
        sanitized_path = link.sub(/\A\s*attachment:\d+\//, "")
        sanitized_path.gsub!(/\+/, " ")

        sanitized_path = Addressable::URI.unencode(sanitized_path)
        File.split(sanitized_path)
      end

      def indexed_path
        link_match = INDEXED_PATH_REGEXP.match(link)
        attachment_id_shard = (link_match[:attachment_id].to_i % 256).to_s

        [attachment_id_shard, link_match[:attachment_id]]
      end
    end
  end
end
