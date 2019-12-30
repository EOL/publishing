class DhDataSet < ActiveRecord::Base
  validates_presence_of :dataset_id
  validates_presence_of :name
end
