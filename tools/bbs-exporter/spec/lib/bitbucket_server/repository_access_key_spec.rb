# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::RepositoryAccessKey do
  let(:project) do
    bitbucket_server.project_model("MIGR8")
  end

  let(:repository) do
    project.repository_model("hugo-pages")
  end

  subject(:repository_access_key) do
    repository.access_key(4)
  end

  describe ".api" do
    it "returns :ssh" do
      expect(described_class.api).to eq(:ssh)
    end
  end

  shared_examples "a RepositoryAccessKey object" do
    describe "#connection" do
      it "returns its parent BitbucketServer::Connection object" do
        expect(repository_access_key.connection).to eq(
          bitbucket_server.connection
        )
      end
    end

    describe "#repository" do
      it "returns its parent BitbucketServer::Repository object" do
        expect(repository_access_key.repository).to eq(repository)
      end
    end

    describe "#id" do
      it "returns the access key ID" do
        expect(repository_access_key.id).to eq(4)
      end
    end

    describe "#path" do
      it "returns an Array of Strings as URI segments" do
        expect(repository_access_key.path).to eq(
          ["projects", "MIGR8", "repos", "hugo-pages", "ssh", "4"]
        )
      end
    end

    describe "#label" do
      it "returns the SSH key label" do
        expect(repository_access_key.label).to eq(
          "MIGR8/hugo-pages access key"
        )
      end
    end

    describe "#text" do
      it "returns the SSH key text" do
        expect(repository_access_key.text).to eq(
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDS+xjiG6p3DoF9wfnQpYjzcMpF1O" \
          "4a9nxUWmR62oCBJxDkrwuuSpgx5NU5Z7AmjJsL911OjP8lAfL1g5mpPvb8rrsAra+4" \
          "GVFywfxyMYJgOjLOOW5yQu4E8Ss40Ow3l3RaoV9noYKsVJtKL037W6T5q024oLb9+f" \
          "W7suI440gC3tMeIMNGyGgv9x32aIh19F6xDwtc1B0CVdkrApNzBfiDHoeU5NxE5zzb" \
          "UvoTbNDvKANzxc8Rcm7xf2VUTDqHFBUh1eknYYru+9GPKfFOIbHWg72hWgBFMpQfhA" \
          "iTfCsaZhO953zbjd0eORjtCJA5y/TIumNIVKQc58fdp+8XrcCYiPWU6bMvRmEtXxKU" \
          "YQRWp48nG6/R0RpVIbfXxo1IAXgl/DOIwZ7Slg9g/P+TxXYxPJJP2rPBsrwqgOQyrl" \
          "E9FWnGUzx9wYLpjcl1U6G92hOeGxdVD0LJqJy3iUW7N8xIE0MlVJG/TsEji3FsjaJO" \
          "OvYWNrlxNsPpyZFAKl3ivG6jFh2hCY4njea8yfMqFEbeInvq5M9evk0HBXGlBRqiNq" \
          "xeF+O2yNp4vL4vepq9tvLSA4z/OTBGbFjwNV0XTxS422tYsRsq4TLErU+x8J97REY8" \
          "UQyRklYFrhIUtJsolbsi7UvPXPtxNtinazTN7Hlh/lMCWWGvnGZWYnsGIzSPOQ== M" \
          "IGR8/hugo-pages access key"
        )
      end
    end

    describe "#fingerprint" do
      it "returns the fingerprint of the SSH key" do
        expect(repository_access_key.fingerprint).to eq(
          "96:88:97:23:a4:00:98:fe:d7:9a:4f:5f:2a:a1:d8:ea"
        )
      end
    end

    describe "#read_only?" do
      it "returns the read only state of the key" do
        expect(repository_access_key.read_only?).to be(true)
      end
    end
  end

  context "when bbs_data is passed", :vcr do
    subject(:repository_access_key) do
      bbs_data = repository.access_key(4).bbs_data

      described_class.new(
        connection:   bitbucket_server.connection,
        bbs_data:     bbs_data,
        parent_model: repository
      )
    end

    it_behaves_like "a RepositoryAccessKey object"
  end

  context "when an id is passed", :vcr do
    it_behaves_like "a RepositoryAccessKey object"
  end
end
