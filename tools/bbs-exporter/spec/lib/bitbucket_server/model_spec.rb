# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::Model do
  subject(:model) { described_class.new }

  let(:connection) { double }

  before(:each) do
    allow(model).to receive(:connection).and_return(connection)
  end

  after(:each) do
    if described_class.instance_variable_defined?(:@api)
      described_class.remove_instance_variable(:@api)
    end
  end

  shared_examples "a method that handles query parameters" do |request_method|
    it "omits nil query params" do
      expect(connection).to receive(request_method).with(
        "activities",
        query: { foo: "bar" }
      )

      model.send(
        request_method,
        "activities",
        query: { foo: "bar", baz: nil }
      )
    end

    it "does not pass query param when all query values are empty" do
      expect(connection).to receive(request_method).with(
        "activities",
        {}
      )

      model.send(
        request_method,
        "activities",
        query: { foo: nil, bar: nil }
      )
    end
  end

  shared_examples "a method that supports BBS API selection" do |request_method|
    before(:each) { described_class.api(api) if api }

    context "when self.api is nil" do
      subject(:api) { nil }

      it "does not pass an api param when an api param is not received" do
        expect(connection).to receive(request_method).with({})

        model.send(request_method)
      end

      it "passes api: :branch when api: :branch is received" do
        expect(connection).to receive(request_method).with(api: :branch)

        model.send(request_method, api: :branch)
      end
    end

    context "when self.api is set to :plugin" do
      subject(:api) { :plugin }

      it "passes api: :plugin when an api param is not received" do
        expect(connection).to receive(request_method).with(api: :plugin)

        model.send(request_method)
      end

      it "passes api: :branch when api: :branch is received" do
        expect(connection).to receive(request_method).with(api: :branch)

        model.send(request_method, api: :branch)
      end

      it "passes api: nil when api: nil is received" do
        expect(connection).to receive(request_method).with(api: nil)

        model.send(request_method, api: nil)
      end
    end
  end

  describe "#get" do
    it_behaves_like "a method that handles query parameters", :get
    it_behaves_like "a method that supports BBS API selection", :get
  end

  describe "#head" do
    it_behaves_like "a method that handles query parameters", :head
    it_behaves_like "a method that supports BBS API selection", :head
  end

  describe ".api" do
    after(:each) { described_class.api(nil) }

    it "returns nil when no value is set" do
      expect(described_class.api).to be_nil
    end

    it "sets and returns values" do
      described_class.api(:branch)
      expect(described_class.api).to eq(:branch)
    end
  end

  describe "#bbs_data" do
    it "calls #get" do
      expect(model).to receive(:get)

      model.bbs_data
    end

    it "caches data from #get" do
      expect(model).to receive(:get).and_return(:bbs_data).once

      2.times { model.bbs_data }
    end
  end

  describe "#new_model" do
    let(:model_class) { double("ModelClass") }

    subject(:child_model) do
      model.new_model(model_class, some: :some, keywords: :keywords)
    end

    it "calls .new on the first parameter with expected parameters" do
      expect(model_class).to receive(:new).with(
        connection:   connection,
        parent_model: model,
        some:         :some,
        keywords:     :keywords
      )

      child_model
    end

    it "returns the object created from model_class.new" do
      returned_object = nil
      allow(model_class).to receive(:new).once { |**k| returned_object = k }

      child_model

      expect(returned_object).to equal(child_model)
    end
  end

  describe "#new_relation" do
    let(:model_class) { double("ModelClass") }
    let(:get_proc) { proc {} }

    subject(:relation) do
      model.new_relation(model_class, &get_proc)
    end

    it "returns a BitbucketServer::Relation instance" do
      expect(relation).to be_a(BitbucketServer::Relation)
    end

    it "sets BitbucketServer::Relation#connection to the given connection" do
      expect(relation.connection).to eq(connection)
    end

    it "sets BitbucketServer::Relation#parent_model to self" do
      expect(relation.parent_model).to eq(model)
    end

    it "sets BitbucketServer::Relation#model_class to the given class" do
      expect(relation.model_class).to eq(model_class)
    end

    it "sets BitbucketServer::Relation#get_proc to the given proc" do
      expect(relation.get_proc).to eq(get_proc)
    end
  end
end
