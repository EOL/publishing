class Page::DescInfo < ApplicationRecord
  belongs_to :page
  validates_presence_of :page_id, :species_count, :genus_count, :family_count

  class << self
    def refresh
      batch = 0
      limit = 1000

      self.transaction do
        puts "begin database transaction"
        begin
          puts "removing old records"
          self.destroy_all

          loop do 
            query = count_batch_query(batch, limit)
            puts "querying batch ##{batch}"
            result = ActiveRecord::Base.connection.select_all(query)
            batch += 1

            puts "got #{result.length} results, writing"
            self.create!(
              result.collect do |r|
                {
                  page_id: r["anc_page_id"],
                  species_count: r["species_count"],
                  genus_count: r["genus_count"],
                  family_count: r["family_count"]
                }
              end
            )

            if result.length < limit
              break
            end
          end

          puts "done!"
        rescue => e
          puts "an exception occurred -- re-raising to roll back transaction"
          raise e
        end
      end
    end

    private
    def count_batch_query(batch, limit)
      "SELECT anc_pages.id AS anc_page_id, "\
      "SUM(CASE WHEN desc_ranks.treat_as = #{Rank.treat_as[:r_species]} THEN 1 ELSE 0 END) species_count, "\
      "SUM(CASE WHEN desc_ranks.treat_as = #{Rank.treat_as[:r_genus]} THEN 1 ELSE 0 END) genus_count, "\
      "SUM(CASE WHEN desc_ranks.treat_as = #{Rank.treat_as[:r_family]} THEN 1 ELSE 0 END) family_count "\
      "FROM node_ancestors AS descs "\
      "JOIN nodes AS desc_nodes ON descs.node_id = desc_nodes.id "\
      "JOIN nodes AS anc_nodes ON descs.ancestor_id = anc_nodes.id "\
      "JOIN ranks AS anc_ranks ON anc_nodes.rank_id = anc_ranks.id "\
      "JOIN ranks AS desc_ranks ON desc_nodes.rank_id = desc_ranks.id "\
      "JOIN pages AS anc_pages ON anc_nodes.page_id = anc_pages.id AND anc_pages.native_node_id = anc_nodes.id "\
      "WHERE anc_ranks.treat_as IS NOT NULL AND anc_ranks.treat_as < #{Rank.treat_as[:r_family]} "\
      "GROUP BY anc_page_id "\
      "ORDER BY anc_page_id "\
      "LIMIT #{limit} "\
      "OFFSET #{batch * limit}"
    end
  end
end
