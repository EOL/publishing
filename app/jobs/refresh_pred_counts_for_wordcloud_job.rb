class RefreshPredCountsForWordcloudJob < ApplicationJob
  def perform
    TbWordcloudData.generate_file 
  end
end
