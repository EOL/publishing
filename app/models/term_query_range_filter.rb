class TermQueryRangeFilter < ActiveRecord::Base
  include TermQueryFilter

  validates_presence_of :from_value
  validates_presence_of :to_value
  validates_presence_of :units_uri

  def op
    :range
  end
end
