# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer do
  let(:has_at_weird_hotdog_characters) do
    bitbucket_server.user("has@weird🌭characters")
  end

  let(:has_percent_weird_hotdog_characters) do
    bitbucket_server.user("has%weird🌭characters")
  end

  let(:application_properties) do
    bitbucket_server.send(:application_properties)
  end

  describe "#get", :vcr do
    let(:commits) do
      bitbucket_server.get(
        "projects", "MIGR8", "repos", "many-commits", "commits",
        pagination: :standard,
        api:        :core
      )
    end

    it "can traverse standard pagination to fetch all records" do
      expect(commits.length).to eq(500)
    end
  end

  describe "#password_or_token" do
    context "using a token" do
      let(:bitbucket_server) do
        described_class.new(
          base_url: "https://example.com",
          token:    "exampletoken"
        )
      end

      it "authenticates with personal access token" do
        expect(bitbucket_server.password_or_token).to eq("exampletoken")
      end
    end

    context "using username and password" do
      let(:bitbucket_server) do
        described_class.new(
          user:     "unit-test",
          base_url: "https://example.com",
          password: "examplepassword"
        )
      end

      it "authenticates with password" do
        expect(bitbucket_server.password_or_token).to eq("examplepassword")
      end
    end
  end

  describe "#user", :vcr do
    it "raises UserNotFound when a user is not found" do
      allow(bitbucket_server).to receive(:get).and_return([])

      expect {
        bitbucket_server.user("waldo")
      }.to raise_error(
        BitbucketServer::UserNotFound,
        "Could not find user with username: waldo"
      )
    end

    context "for users with @, %, and 🌭 (hot dog emoji) in their usernames" do
      it "can fetch has@weird🌭characters" do
        username = has_at_weird_hotdog_characters["name"]
        expect(username).to eq("has@weird🌭characters")
      end

      it "can also fetch has%weird🌭characters (has colliding slug)" do
        username = has_percent_weird_hotdog_characters["name"]
        expect(username).to eq("has%weird🌭characters")
      end
    end
  end

  describe "#application_properties" do
    it "calls #faraday_safe the correct URL" do
      expect(bitbucket_server.connection).to receive(
        :faraday_safe
      ) do |http_method, url|
        uri = Addressable::URI.parse(url)
        expect(uri.path).to eq("/rest/api/1.0/application-properties")
      end

      bitbucket_server.send(:application_properties)
    end
  end

  describe "#get_authenticated_user", :vcr do
    it "retrieves the authenticated user" do
      username = bitbucket_server.send(:get_authenticated_user)
      expect(username).to eq("unit-test")
    end
  end

  describe "#repositories", :vcr do
    it "fetch all repositories" do
      repositories = bitbucket_server.send(:repositories)
      expect(repositories).to_not be_empty
    end
  end
end
