module SearchHelper
  def result_total(results)
    total = 0
    results.compact.each do |r|
      # TODO: this rescue is sloppy, but I was getting cases where the delegated array was nil and there was NO way to
      # test that from "out here." We're not *overly* concerned about errors here...
      total += r.total_count rescue 0
    end
    total
  end

  # BE SURE TO UPDATE THIS METHOD IF YOU ADD ANY NEW SEARCH RESULT TYPES
  def first_type_with_results(results)
    results.find do |result|
      result && result.total_count > 0 
    end&.type

#    pages, articles, images, videos, sounds, collections, users, terms)
#
#    (pages && pages.total_count > 0 && :pages) ||
#    (images && images.total_count > 0 && :images) ||
#    (videos && videos.total_count > 0 && :videos) ||
#    (sounds && sounds.total_count > 0 && :sounds) ||
#    (articles && articles.total_count > 0 && :articles) ||
#    (collections && collections.total_count > 0 && :collections) ||
#    (users && users.total_count > 0 && :users) ||
#    (terms && terms.total_count > 0 && :terms) ||
#    nil
  end
end
