module SearchHelper
  def result_total(results)
    total = 0
    results.each do |r|
      total += r.total_count if r
    end
    total
  end

  # BE SURE TO UPDATE THIS METHOD IF YOU ADD ANY NEW SEARCH RESULT TYPES
  def first_type_with_results(pages, articles, images, videos, sounds, collections, users)
    (pages && pages.total_count > 0 && :pages) ||
    (articles && articles.total_count > 0 && :articles) ||
    (images && images.total_count > 0 && :images) ||
    (videos && videos.total_count > 0 && :videos) ||
    (sounds && sounds.total_count > 0 && :sounds) ||
    (collections && collections.total_count > 0 && :collections) ||
    (users && users.total_count > 0 && :users) ||
    nil
  end
end
