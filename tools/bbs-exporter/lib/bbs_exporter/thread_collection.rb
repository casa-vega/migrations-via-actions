# frozen_string_literal: true

class BbsExporter
  class ThreadCollection
    THREAD_POOL_THREAD_COUNT = 20

    attr_reader :thread_pool, :futures

    def initialize(max_threads = nil)
      @thread_pool = Concurrent::FixedThreadPool.new(max_threads || THREAD_POOL_THREAD_COUNT)
      @futures = []
    end

    def perform_later
      futures << Concurrent::Future.execute(executor: thread_pool) { yield }
    end

    def wait
      futures.each(&:value)
    end
  end
end
