# frozen_string_literal: true

require "spec_helper"

describe BbsExporter::ThreadCollection do
  subject(:thread_collection) { described_class.new }

  after(:each) { thread_collection.thread_pool.kill }

  describe "#perform_later" do
    it "allows 20 threads to run at a time" do
      100.times do
        thread_collection.perform_later { sleep }
      end

      expect(thread_collection.thread_pool.length).to eq(20)
      expect(thread_collection.thread_pool.queue_length).to eq(80)
    end
  end

  describe "#wait" do
    it "calls #value on each of the futures" do
      5.times do
        thread_collection.perform_later { nil }
      end

      thread_collection.futures.each do |future|
        expect(future).to receive(:value)
      end

      thread_collection.wait
    end
  end
end
