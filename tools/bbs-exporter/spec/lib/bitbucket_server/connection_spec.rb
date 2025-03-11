# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::Connection do
  subject(:connection) do
    described_class.new(
      base_url:     "https://example.com",
      user:         "unit-test",
      password:     "hackme",

      open_timeout: 30,
      read_timeout: 300,
      retries:      5,
      ssl_verify:   false
    )
  end

  shared_examples "a connection object with limit options" do |standard, git|
    it "sets limit to #{standard} with no options" do
      expect(connection.faraday).to receive(:get).with(
        "https://example.com/test?limit=#{standard}"
      ).and_return(response_double)

      connection.get_all("test")
    end

    it "sets limit to #{standard} when pagination is :standard" do
      expect(connection.faraday).to receive(:get).with(
        "https://example.com/test?limit=#{standard}"
      ).and_return(response_double)

      connection.get_all("test", pagination: :standard)
    end

    it "sets limit to #{git} when pagination is :git" do
      expect(connection.faraday).to receive(:get).with(
        "https://example.com/test?limit=#{git}"
      ).and_return(response_double)

      connection.get_all("test", pagination: :git)
    end

    it "sets limit from query parameters" do
      expect(connection.faraday).to receive(:get).with(
        "https://example.com/test?limit=500"
      ).and_return(response_double)

      connection.get_all("test", query: { limit: 500 })
    end
  end

  describe "#get_all" do
    let(:response_double) do
      double(
        "FaradayResponse",
        body: {
          "isLastPage" => true,
          "values"     => []
        }
      )
    end

    context "when pagination_limit and git_pagination_limit are not present" do
      subject(:connection) do
        described_class.new(
          base_url: "https://example.com",
          token:    "token"
        )
      end

      it_behaves_like "a connection object with limit options", 250, 5000
    end

    context "when pagination_limit is 100" do
      subject(:connection) do
        described_class.new(
          base_url: "https://example.com",
          token:    "token",

          pagination_limit: 100
        )
      end

      it_behaves_like "a connection object with limit options", 100, 100
    end

    context "when git_pagination_limit is 150" do
      subject(:connection) do
        described_class.new(
          base_url: "https://example.com",
          token:    "token",

          git_pagination_limit: 150
        )
      end

      it_behaves_like "a connection object with limit options", 250, 150
    end

    context "when pagination_limit is 100 and git_pagination_limit is 150" do
      subject(:connection) do
        described_class.new(
          base_url: "https://example.com",
          token:    "token",

          pagination_limit:     100,
          git_pagination_limit: 150
        )
      end

      it_behaves_like "a connection object with limit options", 100, 150
    end

    context "when data_since is 10 and data contains a limit_by parameter" do
      subject(:connection) do
        described_class.new(
          base_url:     "https://example.com",
          user:         "unit-test",
          password:     "hackme",

          data_since:   10.days.ago
        )
      end

      let(:first_page) do
        double(
          "FaradayResponse",
          body: {
            "isLastPage"     => false,
            "nextPageStart"  => "foo",
            "values"         => [
              {"createdDate" => Time.now.to_i * 1000},
              {"createdDate" => (10.days.ago).to_i * 1000}
            ]
          }
        )
      end

      it "returns pages with data newer than 10 days old" do
        expect(connection.faraday).to receive(:get).with(
          "https://example.com/test?limit=250"
        ).and_return(first_page)

        expect(connection.faraday).not_to receive(:get).with(
          "https://example.com/test?limit=250s&start=foo"
        )

        expect(connection.get_all("test", limit_by: "createdDate").size).to be(2)
      end
    end

    context "when data_since is nil" do
      subject(:connection) do
        described_class.new(
          base_url:     "https://example.com",
          user:         "unit-test",
          password:     "hackme",

          data_since:   nil
        )
      end

      context "and data contains a createdDate timestamp" do
        let(:first_page) do
          double(
            "FaradayResponse",
            body: {
              "isLastPage"     => false,
              "nextPageStart"  => "foo",
              "values"         => [
                {"createdDate" => Time.now.to_i * 1000},
                {"createdDate" => (10.days.ago).to_i * 1000}
              ]
            }
          )
        end

        let(:second_page) do
          double(
            "FaradayResponse",
            body: {
              "isLastPage"     => true,
              "values"         => [
                {"createdDate" => (15.days.ago).to_i * 1000},
                {"createdDate" => (20.days.ago).to_i * 1000}
              ]
            }
          )
        end

        it "returns all pages of data" do
          expect(connection.faraday).to receive(:get).with(
            "https://example.com/test?limit=250"
          ).and_return(first_page)

          expect(connection.faraday).to receive(:get).with(
            "https://example.com/test?limit=250&start=foo"
          ).and_return(second_page)

          expect(connection.get_all("test", limit_by: "createdDate").size).to be(4)
        end
      end

      context "and data does not contain a createdDate timestamp" do
        let(:first_page) do
          double(
            "FaradayResponse",
            body: {
              "isLastPage"     => false,
              "nextPageStart"  => "foo",
              "values"         => [{}, {}]
            }
          )
        end

        let(:second_page) do
          double(
            "FaradayResponse",
            body: {
              "isLastPage"     => true,
              "values"         => [{}, {}]
            }
          )
        end

        it "returns all paged data" do
          expect(connection.faraday).to receive(:get).with(
            "https://example.com/test?limit=250"
          ).and_return(first_page)

          expect(connection.faraday).to receive(:get).with(
            "https://example.com/test?limit=250&start=foo"
          ).and_return(second_page)

          expect(connection.get_all("test", limit_by: "createdDate").size).to be(4)
        end
      end
    end
  end

  shared_examples "a method that supports BBS API selection" do |method_name|
    let(:faraday_response) { double("FaradayResponse", body: nil) }

    context "with the api parameter is :branch" do
      subject(:connection_call) do
        connection.send(method_name, "some", "api", "route", api: :branch)
      end

      it "prepends rest/branch-utils/1.0 to the URL path" do
        expect(connection.faraday).to receive(method_name).with(
          "https://example.com/rest/branch-utils/1.0/some/api/route"
        ).and_return(faraday_response)

        connection_call
      end
    end

    context "with the api parameter is :plugin" do
      subject(:connection_call) do
        connection.send(method_name, "some", "api", "route", api: :plugin)
      end

      it "prepends rest/plugins/1.0 to the URL path" do
        expect(connection.faraday).to receive(method_name).with(
          "https://example.com/rest/plugins/1.0/some/api/route"
        ).and_return(faraday_response)

        connection_call
      end
    end

    context "with the api parameter is :core" do
      subject(:connection_call) do
        connection.send(method_name, "some", "api", "route", api: :core)
      end

      it "prepends rest/api/1.0 to the URL path" do
        expect(connection.faraday).to receive(method_name).with(
          "https://example.com/rest/api/1.0/some/api/route"
        ).and_return(faraday_response)

        connection_call
      end
    end

    context "with the api parameter is :ref_restriction" do
      subject(:connection_call) do
        connection.send(
          method_name, "some", "api", "route", api: :ref_restriction
        )
      end

      it "prepends rest/branch-permissions/2.0 to the URL path" do
        expect(connection.faraday).to receive(method_name).with(
          "https://example.com/rest/branch-permissions/2.0/some/api/route"
        ).and_return(faraday_response)

        connection_call
      end
    end

    context "with the api parameter is :ssh" do
      subject(:connection_call) do
        connection.send(method_name, "some", "api", "route", api: :ssh)
      end

      it "prepends rest/keys/1.0 to the URL path" do
        expect(connection.faraday).to receive(method_name).with(
          "https://example.com/rest/keys/1.0/some/api/route"
        ).and_return(faraday_response)

        connection_call
      end
    end
  end

  describe "#get" do
    include_examples "a method that supports BBS API selection", :get
  end

  describe "#head" do
    include_examples "a method that supports BBS API selection", :head
  end

  context "when Faraday options are set" do
    subject(:faraday) { connection.faraday }

    it "sets open timeout" do
      expect(faraday.options.open_timeout).to eq(30)
    end

    it "sets read timeout" do
      expect(faraday.options.timeout).to eq(300)
    end

    it "adds a Faraday::Request::Retry handler" do
      expect(faraday.builder.handlers).to include(Faraday::Request::Retry)
    end

    it "disables SSL verification" do
      expect(faraday.ssl.verify?).to be_falsey
    end
  end

  context "when Faraday options are not set" do
    subject(:faraday) do
      described_class.new(
        base_url: "https://example.com",
        user:     "unit-test",
        password: "hackme"
      ).faraday
    end

    let(:defaults) do
      Faraday.default_connection_options.request
    end

    it "uses default open timeout" do
      expect(faraday.options.open_timeout).to eq(defaults.open_timeout)
    end

    it "uses default read timeout" do
      expect(faraday.options.timeout).to eq(defaults.timeout)
    end

    it "does not add a Faraday::Request::Retry handler" do
      expect(faraday.builder.handlers).to_not include(Faraday::Request::Retry)
    end

    it "enforces SSL verification" do
      expect(faraday.ssl.verify?).to be_truthy
    end
  end

  describe "#initialize" do
    context "with a valid URL, username, and password" do
      subject(:connection) do
        described_class.new(
          base_url:     "https://example.com",
          user:         "unit-test",
          password:     "hackme"
        )
      end

      it "can specify records per page" do
        url = connection.encode_url(
          path: %w(some path),
          query: {
            limit: 1000
          }
        )

        expect(url).to eq(
          "https://example.com/some/path?limit=1000"
        )
      end

      it "can specify which page to fetch" do
        url = connection.encode_url(
          path: %w(some path),
          query: {
            start: 25
          }
        )

        expect(url).to eq("https://example.com/some/path?start=25")
      end

      it "can specify records per page and which page to fetch" do
        url = connection.encode_url(
          path: %w(some path),
          query: {
            limit: 1000,
            start: 25
          }
        )

        expect(url).to eq(
          "https://example.com/some/path?limit=1000&start=25"
        )
      end
    end

    context "with a bad URL" do
      let(:bad_url) { "ssh://example.com" }

      subject(:connection) do
        described_class.new(
          base_url: bad_url,
          user:     "unit-test",
          password: "hackme"
        )
      end

      it "raises BitbucketServer::Connection::InvalidBaseUrl" do
        expect { subject }.to raise_error(
          BitbucketServer::Connection::InvalidBaseUrl,
          "#{bad_url} is not a valid URL!"
        )
      end
    end
  end

  describe "#inspect" do
    context "when using basic authentication" do
      subject(:connection) do
        described_class.new(
          base_url: "https://example.com",
          user:     "unit-test",
          password: "hackme"
        )
      end

      it "masks password on inspect" do
        inspected = subject.inspect
        expect(inspected).not_to include("hackme")
        expect(inspected).to include("@password=\"*******\"")
      end
    end

    context "when using token authentication" do
      subject(:connection) do
        described_class.new(
          base_url: "https://example.com",
          user:     "unit-test",
          token:    "123456"
        )
      end

      it "masks token on inspect" do
        inspected = subject.inspect
        expect(inspected).not_to include("123456")
        expect(inspected).to include("@token=\"*******\"")
      end
    end
  end

  describe "#faraday" do
    context "when user is provided but token and password are not" do
      subject(:faraday) do
        described_class.new(
          base_url: "https://example.com",
          user:     "unit-test"
        ).faraday
      end

      it "raises BitbucketServer::Connection::MissingCredentialsError" do
        expect { faraday }.to raise_error(
          BitbucketServer::Connection::MissingCredentialsError
        )
      end
    end

    context "when password is provided but user is not" do
      subject(:faraday) do
        described_class.new(
          base_url: "https://example.com",
          password: "examplepassword"
        ).faraday
      end

      it "raises BitbucketServer::Connection::MissingCredentialsError" do
        expect { faraday }.to raise_error(
          BitbucketServer::Connection::MissingCredentialsError
        )
      end
    end

    context "when token is provided but user and password is not" do
      subject(:faraday) do
        described_class.new(
          base_url: "https://example.com",
          token:    "exampletoken"
        ).faraday
      end

      it "returns a Faraday::Connection" do
        expect(faraday).to be_a(Faraday::Connection)
      end
    end

    it "uses the FaradayMiddleware::Gzip middleware" do
      expect(connection.faraday.builder.handlers).to include(
        FaradayMiddleware::Gzip
      )
    end
  end

  describe "#faraday_safe", :vcr do
    let(:project_model) do
      bitbucket_server.project_model("doesnt-exist")
    end

    it "calls #faraday with the faraday_method param" do
      expect(connection.faraday).to receive(:get).with(
        "https://example.com"
      )

      connection.faraday_safe(:get, "https://example.com")
    end

    it "raises Faraday::ConnectionFailed with exception message" do
      expect(connection.faraday).to receive(:get).and_raise(
        Faraday::ConnectionFailed, "message"
      )

      expect {
        connection.faraday_safe(:get, "https://example.com")
      }.to raise_error(Faraday::ConnectionFailed, "message")
    end

    it "raises Faraday::TimeoutError with retry count and URL" do
      expect(connection.faraday).to receive(:get).and_raise(
        Faraday::TimeoutError
      )

      expect {
        connection.faraday_safe(:get, "https://example.com")
      }.to raise_error(
        Faraday::TimeoutError,
        "Timed out 5 times during GETs to https://example.com"
      )
    end

    it "raises Faraday::ClientError with a message" do
      url = bitbucket_server.connection.encode_url(
        path: project_model.path,
        api:  :core
      )

      expect {
        bitbucket_server.connection.faraday_safe(:get, url)
      }.to raise_error do |exception|
        expect(exception.message).to eq(
          "404 on GET to #{url}: Project doesnt-exist does not exist."
        )
      end
    end

    it "calls #around_request" do
      test_double = double("TestDouble")

      connection.around_request = proc do |faraday_method, url, &request|
        test_double.faraday_method(faraday_method)
        test_double.url(url)

        request.call
      end

      expect(test_double).to receive(:faraday_method).with(:get)
      expect(test_double).to receive(:url).with("https://example.com")

      expect(connection.faraday).to receive(:get)

      connection.faraday_safe(:get, "https://example.com")
    end
  end
end
