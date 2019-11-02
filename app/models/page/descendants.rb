require "csv"

class Page::Descendants
  COUNT_FILE_PATH = Rails.root.join("data", "higher_order_desc_counts.csv")

  Counts = Struct.new(:species, :genus, :family) do
    class << self
      def empty
        Counts.new(0, 0, 0)
      end
    end

    def empty?
      self.species == 0 && self.genus == 0 && self.family == 0
    end
  end

  class << self
    def load
      @counts = {}

      CSV.foreach(COUNT_FILE_PATH, headers: true) do |row|
        page_id = Integer(row["anc_page_id"])
        @counts[page_id] = Counts.new(
          Integer(row["species_count"]),
          Integer(row["genus_count"]),
          Integer(row["family_count"])
        )
      end      

      @loaded = true
    end

    def counts(page_id)
      if !@loaded
        Rails.logger.error("Descendant counts not loaded!")
        return Counts.empty
      end

      if @counts.include?(page_id)
        @counts[page_id]
      else
        Counts.empty
      end
    end 

    def generate_counts_file
      batch = 0
      limit = 1000

      file_path = Rails.application.root.join("data", "higher_order_desc_counts.csv")
      puts "opening file #{file_path} for writing"
      CSV.open(file_path, "wb") do |csv|
        csv << ["anc_page_id", "species_count", "genus_count", "family_count"]
        loop do 
          query = self.count_batch_query(batch, limit)
          puts "querying batch ##{batch}"
          result = ActiveRecord::Base.connection.select_all(query)
          batch += 1

          puts "got #{result.length} results, writing"
          result.each do |r|
            csv << [r["anc_page_id"], r["species_count"], r["genus_count"], r["family_count"]]
          end

          if result.length < limit
            break
          end
        end
      end

      puts "done!"
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


