# frozen_string_literal: true

require "sqlite3"
require "active_record"

module Db
  class Connection
    class << self
      def establish(database_path:, logger: nil)
        ActiveRecord::Migration.verbose = false
        ActiveRecord::Base.logger = logger unless logger.nil?

        ActiveRecord::Base.establish_connection(
          adapter: "sqlite3",
          database: database_path
        )

        ActiveRecord::Schema.define do
          create_table :extracted_resources, force: true do |t|
            t.string  :model_type, null: false
            t.string  :model_url, null: false
            t.integer :order
            t.string  :data

            t.index :model_type
            t.index :model_url
          end
        end
      end
    end
  end
end
