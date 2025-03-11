# frozen_string_literal: true

class BitbucketServer
  class Connection
    DEFAULT_PAGINATION_LIMIT = 250
    DEFAULT_GIT_PAGINATION_LIMIT = 5000

    API_PATHS = {
      branch:          %w(rest branch-utils 1.0),
      plugin:          %w(rest plugins 1.0),
      core:            %w(rest api 1.0),
      ref_restriction: %w(rest branch-permissions 2.0),
      ssh:             %w(rest keys 1.0)
    }

    URL_TEMPLATE = Addressable::Template.new(
      "{+base_url}{/api_path*}{/path*}{?query*}"
    )

    class InvalidBaseUrl < StandardError; end

    attr_reader :base_url, :user, :password, :token, :read_timeout,
      :open_timeout, :retries, :pagination_limit, :git_pagination_limit,
      :ssl_verify, :data_since

    attr_accessor :around_request

    def initialize(
      base_url:, user: nil, password: nil, token: nil, read_timeout: nil,
      open_timeout: nil, retries: nil, pagination_limit: nil,
      git_pagination_limit: nil, ssl_verify: nil, around_request: nil,
      data_since: nil
    )
      @base_url = base_url

      @user = user
      @password = password
      @token = token

      @read_timeout = read_timeout
      @open_timeout = open_timeout
      @retries = retries

      @pagination_limit = pagination_limit || DEFAULT_PAGINATION_LIMIT

      @git_pagination_limit = [
        git_pagination_limit,
        pagination_limit,
        DEFAULT_GIT_PAGINATION_LIMIT
      ].find(&:present?)

      @ssl_verify = ssl_verify

      @around_request = around_request || proc { |&r| r.call }

      @data_since = data_since || Time.at(0)

      validate_base_url!
    end

    # Sanitizes creds on .inspect
    def inspect
      inspected = super

      inspected.gsub! @password, "*******" if @password
      inspected.gsub! @token, "*******" if @token

      inspected
    end

    def base_url_valid?
      @base_url =~ URI::regexp(%w(http https))
    end

    def validate_base_url!
      unless base_url_valid?
        raise(InvalidBaseUrl, "#{base_url} is not a valid URL!")
      end
    end

    def basic_authenticated?
      !!(user && password)
    end

    def token_authenticated?
      !!token
    end

    # The path to the http cache on disk.
    #
    # @return [String]
    def http_cache_path
      Dir.mktmpdir("bbs_exporter_http_cache")
    end

    # Faraday's cache store.
    #
    # @return [ActiveSupport::Cache::FileStore]
    def http_cache
      @http_cache ||= ActiveSupport::Cache::FileStore.new(http_cache_path)
    end

    # The Faraday object for making requests to Bitbucket Server API
    #
    # @return [Faraday::Connection]
    def faraday
      @faraday ||= Faraday.new ssl: { verify: ssl_verify } do |faraday|
        authenticate!(faraday)

        faraday.request(:retry,
                        max: retries,
                        interval: 0.05,
                        interval_randomness: 0.5,
                        backoff_factor: 2,
                        exceptions: Faraday::Request::Retry::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed, Faraday::SSLError]) if retries
        faraday.options.timeout = read_timeout if read_timeout
        faraday.options.open_timeout = open_timeout if open_timeout

        faraday.request  :url_encoded  # Form-encode POST params

        faraday.response :raise_error
        faraday.response :json, content_type: /\bjson$/

        faraday.use      :http_cache, store: http_cache, serializer: Marshal
        faraday.use      Faraday::CacheHeaders
        faraday.use      :gzip
      end
    end

    def encode_url(path: nil, query: nil, api: nil)
      URL_TEMPLATE.expand(
        base_url: base_url,
        api_path: API_PATHS[api],
        path:     path,
        query:    query
      ).to_s
    end

    # A wrapper for calling `faraday` that includes better errors in
    # exceptions.
    #
    # @param [String] url URL to make GET request for.
    # @return [Faraday::Response] Response data.
    def faraday_safe(faraday_method, url)
      around_request.call(faraday_method, url) do
        faraday.send(faraday_method, url)
      end
    rescue Faraday::ConnectionFailed => exception
      raise($!, exception.message)
    rescue Faraday::TimeoutError => exception
      timeout_error_with_message(exception, url)
    rescue Faraday::ClientError => exception
      client_error_with_message(exception, url)
    end

    # Get a single record or not paginated collection of records.
    #
    # @param [Array<String>] path The URL path to send the GET request to.
    # @option query Hash Optionally include query parameters with the request.
    # @option api nil Use the base URL without an API.
    # @option api :branch Use the branch API.
    # @option api :plugin Use the plugin API.
    # @option api :core Use the core API.
    # @option api :ref_restriction Use the ref restriction API.
    # @option api :ssh Use the ssh API.
    # @return [Array,Hash] The response body.
    def get_one(*path, query: nil, api: nil)
      url = encode_url(path: path, query: query, api: api)
      faraday_safe(:get, url).body
    end

    # Fetch records and auto paginate using Bitbucket Server's documented API
    # pagination.
    #
    # @param [Array<String>] path The URL path to send the GET request to.
    # @option query Hash Optionally include query parameters with the request.
    # @option api nil Use the base URL without an API.
    # @option api :branch Use the branch API.
    # @option api :plugin Use the plugin API.
    # @option api :core Use the core API.
    # @option api :ref_restriction Use the ref restriction API.
    # @option api :ssh Use the ssh API.
    # @option pagination :standard Aggregate paginated results using a standard
    #   pagination limit.
    # @option pagination :git Aggregate paginated results using a pagination
    #   limit optimized for git endpoints.
    # @return [Array] Aggregated data from paginated responses.
    def get_all(*path, query: nil, api: nil, pagination: :standard, limit_by: nil)
      query = {} if query.nil?

      case pagination
      when :standard
        query[:limit] ||= pagination_limit
      when :git
        query[:limit] ||= git_pagination_limit
      end

      body = {}
      oldest_timestamp = Time.now

      [].tap do |body_values|
        until body["isLastPage"] == true || oldest_timestamp < @data_since do
          url = encode_url(
            path:  path,
            query: query,
            api:   api
          )

          body = faraday_safe(:get, url).body
          body_values.concat(body["values"])

          last = body["values"].last

          # Divide by 1000 to remove ms from unix epoch timestamp

          unless limit_by.nil?
            oldest_timestamp = Time.at(last[limit_by] / 1000) unless last.nil? || last[limit_by].nil?
          end

          query[:start] = body["nextPageStart"]
        end
      end
    end

    # Make a GET request to Bitbucket Server's API.
    #
    # @param [Array<String>] path The URL path to send the GET request to.
    # @option query Hash Optionally include query parameters with the request.
    # @option api nil Use the base URL without an API.
    # @option api :branch Use the branch API.
    # @option api :plugin Use the plugin API.
    # @option api :core Use the core API.
    # @option api :ref_restriction Use the ref restriction API.
    # @option api :ssh Use the ssh API.
    # @option pagination nil Return data without aggregating paginated results.
    # @option pagination :standard Aggregate paginated results using a standard
    #   pagination limit.
    # @option pagination :git Aggregate paginated results using a pagination
    #   limit optimized for git endpoints.
    # @return The response body.
    def get(*path, query: nil, api: nil, pagination: nil, limit_by: nil)
      if pagination
        get_all(*path, query: query, api: api, pagination: pagination, limit_by: limit_by)
      else
        get_one(*path, query: query, api: api)
      end
    end

    def head(*path, query: nil, api: nil)
      url = encode_url(path: path, query: query, api: api)
      faraday_safe(:head, url)
    end

    private

    def authenticate!(faraday)
      if token_authenticated?
        faraday.request(:authorization, "Bearer", token)
      elsif basic_authenticated?
        faraday.request(:basic_auth, user, password)
      else
        raise MissingCredentialsError
      end
    end

    def client_error_with_message(exception, url)
      raise($!) if exception.is_a?(Faraday::SSLError)

      message = bbs_error_message(exception, url)
      raise(exception, message)
    end

    def bbs_error_message(exception, url)
      response = exception.response
      message = "#{response[:status]} on GET to #{url}"

      if response[:body].is_a?(Hash) && response[:body].key?("errors")
        errors = response[:body]["errors"].map { |e| e["message"] }.join(" ")
        message += ": #{errors}"
      end

      message
    end

    def timeout_error_with_message(exception, url)
      if retries
        message = "Timed out #{retries} times during GETs to #{url}"
      else
        message = "Timed out during GET to #{url}"
      end

      raise(exception, message)
    end

    class MissingCredentialsError < StandardError
      def message
        "Must define `BITBUCKET_SERVER_API_TOKEN` or `BITBUCKET_SERVER_API_USERNAME` AND `BITBUCKET_SERVER_API_PASSWORD`"
      end
    end
  end
end
