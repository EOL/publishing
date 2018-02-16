class TermQueryObjectTermObject < ActiveRecord::Base
  has_one :term_query_filter, :as => :object
  validates_presence_of :uri
end
