class CommentsJob < ApplicationJob
  def perform
    Rails.logger.warn("START Comments.delete_empty_comment_topics")
    max_tries = 100
    loop do
      count = Comments.delete_empty_comment_topics
      break if count.zero?
      max_tries -= 1
      break unless max_tries.positive?
    end
    Rails.logger.warn("END Comments.delete_empty_comment_topics")
  end
end
