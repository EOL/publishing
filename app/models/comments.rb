# NOTE: yes, I pluralized this. It's a plural thing.
class Comments
  class << self
    def discourse
      return @client if @client
      discourse_url
      return Rails.logger.error("Missing discourse_url") if discourse_url.nil?
      return Rails.logger.error("Missing discourse_url") if
        Rails.application.secrets.discourse_key.nil?
      return Rails.logger.error("Missing discourse_url") if
        Rails.application.secrets.discourse_user.nil?
      @client = DiscourseApi::Client.new(
        discourse_url,
        Rails.application.secrets.discourse_key,
        Rails.application.secrets.discourse_user
      )
    end

    def discourse_url
      @discourse_url ||= Rails.application.secrets.discourse_url
    end

    def post_url(post)
      "#{discourse_url}/t/#{post["topic_slug"]}/#{post["topic_id"]}"
    end

    def topic_url(topic)
      "#{discourse_url}/t/#{topic["slug"]}/#{topic["id"]}"
    end

    def empty_comment_topics
      discourse.latest_topics.select do |t|
        t['slug'] =~ /\Acomments-on-.*-page-\d+\Z/ &&
        t['posts_count'] <= 1 && !t['archived'] &&
        t['visible'] &&
        t['like_count'].zero? &&
        t['vote_count'].nil?
      end
    end

    def delete_empty_comment_topics
      client = discourse
      count = 0
      empty_comment_topics.each do |topic|
        next unless Time.parse(topic['created_at']) < 1.hour.ago.utc
        msg = "** Removing topic #{topic_url(topic)}"
        puts msg
        Rails.logger.warn(msg)
        # Feeling harsh? Delete it entirely:
        client.delete_topic(topic['id'])
        # Just want to lock it down? (The problem with this is that it still shows up.) Archive it:
        # client.change_topic_status(topic['slug'], topic['id'],
        #   { status: 'archived', enabled: true, api_username: Rails.application.secrets.discourse_user })
        count += 1
      end
      count
    end
  end
end
