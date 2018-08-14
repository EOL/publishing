class CommentsJob < ActiveJob::Base
  def perform
    Rails.logger.warn("START Comments.delete_empty_comment_topics")
    Comments.delete_empty_comment_topics
    Rails.logger.warn("END Comments.delete_empty_comment_topics")
  end
end
