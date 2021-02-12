module GraphPageRankPopulator
  class << self
    def run
      update_count = 0

      Page.includes(native_node: :rank).references(native_node: :rank).where.not('ranks.id': nil).find_in_batches.with_index do |pages, i|
        puts "handling batch #{i}"

        update_data = pages.map do |page|
          { page_id: page.id, rank: page.rank.treat_as.to_s[2..] } # treat_as is prefixed with r_...
        end

        result = ActiveGraph::Base.query(%Q(
          WITH $update_data AS data
          UNWIND data as datum
          MATCH (page:Page)
          WHERE page.page_id = datum.page_id
          SET page.rank = datum.rank
          RETURN count(*) AS count
        ), update_data: update_data)
        count = result.first[:count]
        update_count += count

        puts "Updated #{count} nodes, #{update_count} so far."
      end 

      puts "Done. Updated #{update_count} nodes."
    end
  end
end

