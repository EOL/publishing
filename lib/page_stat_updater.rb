class PageStatUpdater
  BATCH_SIZE = 100
  
  class << self
    def run
      batch = 0
      page_count = PageNode.query_as(:p).where('(:Page)-[:parent*2]->(p)').count('distinct p')
      num_batches = page_count / BATCH_SIZE
      num_batches += BATCH_SIZE if page_count % BATCH_SIZE > 0
      time_elapsed = 0

      while batch < num_batches # batch starts at 0, hence <
        start = Time.now
        puts "Updating page batch #{batch + 1} / #{num_batches} (x #{BATCH_SIZE})"
        update_batch(batch)
        batch += 1
        time_elapsed += (Time.now - start)
        avg = time_elapsed / (batch + 1)
        minutes_remain = (num_batches - batch - 1) * avg / 60
        time_remain_str = minutes_remain > 60 ? "#{minutes_remain / 60} hours" : "#{minutes_remain} minutes"
        puts "Estimated time remaining: #{time_remain_str}"
      end 
    end

    def update_batch(batch)
      q = %Q(
        MATCH (anc:Page)
        WHERE (:Page)-[:parent*2]->(anc)
        WITH anc
        ORDER BY anc.page_id
        SKIP #{batch * BATCH_SIZE}
        LIMIT #{BATCH_SIZE}
        MATCH (desc:Page)-[:parent*0..]->(anc)
        OPTIONAL MATCH (subj_page:Page)-[:trait|inferred_trait]->(obj_trait:Trait)-[:object_page]->(desc)
        WITH anc, desc, collect(DISTINCT obj_trait) AS obj_traits, collect(DISTINCT subj_page) AS desc_obj_trait_subjs
        OPTIONAL MATCH (desc)-[:trait|inferred_trait]->(trait:Trait)
        WITH anc, desc, sum(CASE WHEN trait IS NULL THEN 0 ELSE 1 END) AS desc_subj_trait_row_count, obj_traits, desc_obj_trait_subjs
        UNWIND obj_traits AS obj_trait
        WITH anc, count(DISTINCT desc) AS desc_count, sum(desc_subj_trait_row_count) AS subj_trait_row_count, count(obj_trait) AS obj_trait_count, collect(desc_obj_trait_subjs) AS desc_obj_trait_subjs_lists
        UNWIND desc_obj_trait_subjs_lists AS obj_trait_subjs
        UNWIND obj_trait_subjs AS obj_trait_subj
        WITH anc, desc_count, subj_trait_row_count, obj_trait_count, count(DISTINCT obj_trait_subj) AS obj_trait_distinct_subj_count
        SET anc.descendant_count = desc_count
        SET anc.obj_trait_count = obj_trait_count
        SET anc.obj_trait_distinct_subj_count = obj_trait_distinct_subj_count
        SET anc.subj_trait_row_count = subj_trait_row_count
      )

      TraitBank.query(q)
    end
  end
end

