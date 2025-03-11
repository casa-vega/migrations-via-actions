# frozen_string_literal: true

class ExtractedResource < ActiveRecord::Base
  validates :model_type, :model_url, presence: true

  scope :resources, ->(model_type, page_size, index) do
    where(model_type: model_type).
    where.not(data: nil).
    limit(page_size).
    offset(page_size * (index - 1)).
    order(Arel.sql "\"extracted_resources\".\"order\" IS NULL, \"extracted_resources\".\"order\" ASC, \"extracted_resources\".\"id\" ASC")
  end
end
