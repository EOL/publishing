every 1.day, at: '3:00 am' do
  runner "CacheWarmer.warm"
end

every 1.day, at: '3:30 am' do
  runner "TraitBank::Terms.warm_caches"
end

every 1.day, at: '4:00 am' do
  runner "Comments.delete_empty_comment_topics"
end
