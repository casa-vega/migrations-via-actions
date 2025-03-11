# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::Relation do
  let(:connection) { instance_double("Connection") }
  let(:model_class) { double("ModelClass") }
  let(:parent_model) { instance_double("ParentModel") }
  let(:get_proc) { proc { [1, 2, 3] } }

  subject(:relation) do
    described_class.new(
      connection:   connection,
      model_class:  model_class,
      parent_model: parent_model,
      get_proc:     get_proc
    )
  end

  it "is enumerable" do
    expect(described_class.included_modules).to include(Enumerable)
  end

  describe "#initialize" do
    it "does not call #get_proc.call" do
      expect(get_proc).to_not receive(:call)

      relation
    end
  end

  describe "#each" do
    before(:each) do
      allow(model_class).to receive(:new) { |**k| k }
    end

    context "when a block is not given" do
      subject(:each) { relation.each }

      it "caches values from calling get_proc" do
        expect(get_proc).to receive(:call).and_call_original.once

        2.times { each }
      end

      it "returns an Enumerator object" do
        expect(each).to be_a(Enumerator)
      end

      it "includes new model_class objects from each get_proc value" do
        expect(each.to_a).to eq(
          [
            { connection: connection, bbs_data: 1, parent_model: parent_model },
            { connection: connection, bbs_data: 2, parent_model: parent_model },
            { connection: connection, bbs_data: 3, parent_model: parent_model }
          ]
        )
      end
    end

    context "when a block is given" do
      subject(:each) do
        [].tap do |yielded|
          relation.each do |model_class_object|
            yielded << model_class_object
          end
        end
      end

      it "caches values from calling get_proc" do
        expect(get_proc).to receive(:call).and_call_original.once

        2.times { each }
      end

      it "yields new model_class objects from each get_proc value" do
        expect(each).to eq(
          [
            { connection: connection, bbs_data: 1, parent_model: parent_model },
            { connection: connection, bbs_data: 2, parent_model: parent_model },
            { connection: connection, bbs_data: 3, parent_model: parent_model }
          ]
        )
      end
    end
  end
end
