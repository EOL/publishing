class CommentsController < ApplicationController
  
  def topic
   @topic = CLIENT.create_topic(title: "#{request.referer}", raw: "Discussion about '#{params[:page]}'")
    respond_to do |format|
      format.js {}
    end
  end
 
  def new_post
    topic = CLIENT.search("#{request.referer}")
    raw = params[:post]
    id = topic['topics'].first['id']
    CLIENT.create_post(topic_id: id, raw: raw)
    respond_to do |format|
      format.js {render template: "/comments/topic.js.erb"}
    end
  end

   def get_posts
    get_topic = CLIENT.search("#{request.referer}")
    topic_id  = get_topic['topics'].first['id']
    @topic = CLIENT.topic(topic_id)
    @posts = @topic['post_stream']['posts']
   end
   
end