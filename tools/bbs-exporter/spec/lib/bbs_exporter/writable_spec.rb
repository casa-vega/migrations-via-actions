# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::Writable do
  let(:pseudo_exporter) do
    PseudoExporter.new(
      model:            pseudo_model,
      bitbucket_server: bitbucket_server
    )
  end

  let(:pseudo_model) do
    PseudoModel.new.tap do |model|
      model[:repository] = {
        "links" => {
          "self" => [
            {"href" => "http://hostname.com/path"}
          ]
        }
      }
    end
  end

  let(:serializer) { double BbsExporter::RepositorySerializer }

  before(:each) do
    PseudoExporter.include(BbsExporter::Writable)
    allow(BbsExporter::RepositorySerializer).to receive(:new).and_return(serializer)
    # Call current_export to initialize database connection
    pseudo_exporter.current_export
  end

  describe "#serialize" do
    context "when the archiver has written this model before" do
      before(:each) do
        ExtractedResource.create(model_type: "repository", model_url: "http://hostname.com/path")
      end

      it "does not write the model" do
        expect { pseudo_exporter.serialize("repository", pseudo_model) }.not_to change(ExtractedResource, :count)
      end

      it "returns false" do
        expect(serializer).not_to receive(:serialize)
        expect(pseudo_exporter.serialize("repository", pseudo_model)).to be_falsey
      end
    end

    context "when the archiver has not written this model before" do
      it "does writes the model" do
        expect(serializer).to receive(:serialize)
        expect do
          pseudo_exporter.serialize("repository", pseudo_model)
        end.to change { ExtractedResource.count }.by(1)
      end

      it "returns true" do
        expect(serializer).to receive(:serialize)
        expect(pseudo_exporter.serialize("repository", pseudo_model)).to be_truthy
      end
    end
  end
end
