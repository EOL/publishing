class TermQueryNumericFilter < ActiveRecord::Base
  has_one :term_query_filter, :as => :object
  validates_presence_of :value
  validates_presence_of :op
  validates_presence_of :units_uri

  enum :op => {
    :eq => 0,
    :gt => 1,
    :lt => 2
  }
end
