# frozen_string_literal: true

require "spec_helper"

require "tmpdir"
require "fileutils"

describe BbsExporter::SerializedModelWriter do
  subject do
    BbsExporter::SerializedModelWriter.new(dir, "organization")
  end

  let(:data) do
    {
      "something" => "this is a thing",
      "something2" => "this is also a thing"
    }
  end
  let(:dir) { Dir.mktmpdir("bbs-export-test") }

  before do
    Db::Connection.establish(database_path: ":memory:")
  end

  after do
    FileUtils.remove_entry_secure(dir)
  end

  describe "#write_models" do
    it "rolls over a file" do
      101.times do |i|
        ExtractedResource.create(
          model_type: "organization",
          model_url: "https://example.com/org/#{i}",
          data: {organization: i}.to_json
        )
      end

      subject.write_models

      expect(data_in("organizations_000001.json").size).to eq(100)
      expect(data_in("organizations_000002.json").size).to eq(1)
    end

    it "jsonifies the data" do
      ExtractedResource.create(
        model_type: "organization",
        model_url: "https://example.com",
        data: data.to_json
      )
      subject.write_models

      expect(data_in("organizations_000001.json")).to eq([data])
    end

    it "does not include resources with no data" do
      ExtractedResource.create(model_type: "organization", model_url: "https://example.com/org")
      subject.write_models

      expect(file_exists?("organizations_000001.json")).to be_falsy
    end

    context "when extracted resources contain an order" do
      let(:expected_data) { 10.times.map { |i| { "data" => i } } }

      it "orders the archive" do
        expected_data.size.times do |i|
          ExtractedResource.create(
            model_type: "organization",
            model_url: "https://example.com/org/#{i}",
            data: expected_data[i].to_json,
            order: expected_data.size - i
          )
        end

        subject.write_models

        expect(data_in("organizations_000001.json")).to eq(expected_data.reverse)
      end

      it "places entries with an order before entries without an order" do
        last_entry = { "message" => "put me last!" }
        ExtractedResource.create(
          model_type: "organization",
          model_url: "https://example.com",
          data: last_entry.to_json,
          order: nil
        )

        expected_data.size.times do |i|
          ExtractedResource.create(
            model_type: "organization",
            model_url: "https://example.com/org/#{i}",
            data: expected_data[i].to_json,
            order: i
          )
        end

        subject.write_models

        expect(data_in("organizations_000001.json").last).to eq(last_entry)
      end
    end
  end

  def data_in(filename)
    path = File.join(dir, filename)
    json_data = File.read(path)
    JSON.load(json_data)
  end

  def file_exists?(filename)
    path = File.join(dir, filename)
    File.exist?(path)
  end
end
