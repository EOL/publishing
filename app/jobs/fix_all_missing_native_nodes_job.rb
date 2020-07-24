# Crono job for expiring old downloads that didn't finish.
class FixAllMissingNativeNodesJob < ApplicationJob
  def perform
    Rails.logger.warn("START FixAllMissingNativeNodesJob")
    Page.fix_all_missing_native_nodes
    Rails.logger.warn("END FixAllMissingNativeNodesJob.")
  end
end
