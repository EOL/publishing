class TermQueryRangeFilter < ActiveRecord::Base
  has_one :term_query_filter, :as => :object
  validates_presence_of :from_value
  validates_presence_of :to_value
  validates_presence_of :units_uri
  validates_presence_of :pred_uri
end
