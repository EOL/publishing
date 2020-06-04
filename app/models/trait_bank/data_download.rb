require "zip"
require "csv"
require "set"

class TraitBank
  class DataDownload
    BATCH_SIZE = 1000

    attr_reader :count

    class << self
      # options:
      #   - force_new: true -- always create and background_build a UserDownload
      def term_search(term_query, user_id, url, options={})
        count = TraitBank.term_search(
          term_query,
          { count: true },
        ).primary_for_query(term_query)

        UserDownload.create_and_run_if_needed!({
          :user_id => user_id,
          :count => count,
          :search_url => url
        }, term_query, options)
      end

      def path
        return @path if @path
        @path = Rails.public_path.join('data', 'downloads')
        FileUtils.mkdir_p(@path) unless Dir.exist?(path)
        @path
      end
    end

    def initialize(term_query, count, url)
      raise TypeError.new("count cannot be nil") if count.nil?
      @query = term_query
      @options = { :per => BATCH_SIZE, :meta => true }
      # TODO: would be great if we could detect whether a version already exists
      # for download and use that.

      @base_filename = "#{Digest::MD5.hexdigest(@query.as_json.to_s)}_#{Time.now.to_i}"
      @url = url
      @count = count
    end

    def background_build
      # OOOOPS! We don't actually want to do this here, we want to call a DataDownload. ...which means this logic is in the wrong place. TODO - move.
      # TODO - I am not *entirely* confident that this is memory-efficient
      # with over 1M hits... but I *think* it will work.
      Delayed::Worker.logger.info("beginning data download query for #{@query.to_s}")

      hashes = []
      TraitBank.batch_term_search(@query, @options, @count) do |batch|
        hashes += batch
      end


---
LIMIT goes after "WITH DISTINCT row"
---
WITH "MATCH (page:Page), (page)-[:trait|:inferred_trait]->(trait:Trait), (trait)-[:predicate]->(predicate:Term)-[:parent_term|:synonym_of*0..]->(:Term{ uri: 'http://eol.org/schema/terms/Present' })
OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
OPTIONAL MATCH (trait)-[:normal_units_term]->(normal_units:Term)
OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
OPTIONAL MATCH (trait)-[:supplier]->(resource:Resource)
OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term)
OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term)
OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term)
OPTIONAL MATCH (meta)-[:sex_term]->(meta_sex_term:Term)
OPTIONAL MATCH (meta)-[:lifestage_term]->(meta_lifestage_term:Term)
OPTIONAL MATCH (meta)-[:statistical_method_term]->(meta_statistical_method_term:Term)
RETURN page.page_id, trait.eol_pk, trait.measurement, trait.object_page_id, trait.sample_size, trait.citation,
  trait.source, trait.remarks, trait.method, units.uri, units.name, units.definition, statistical_method_term.uri,
  statistical_method_term.name, statistical_method_term.definition, sex_term.uri, sex_term.name, sex_term.definition,
  lifestage_term.uri, lifestage_term.name, lifestage_term.definition, resource.resource_id, meta_predicate.uri,
  meta_predicate.name, meta_predicate.definition, meta_units_term.uri, meta_units_term.name, meta_units_term.definition,
  meta_object_term.uri, meta_object_term.name, meta_object_term.definition, meta_sex_term.uri, meta_sex_term.name,
  meta_sex_term.definition, meta_lifestage_term.uri, meta_lifestage_term.name, meta_lifestage_term.definition,
  meta_statistical_method_term.uri, meta_statistical_method_term.name, meta_statistical_method_term.definition
LIMIT 5000000" AS query
CALL apoc.export.csv.query(query, 'present.csv', {})
YIELD file, source, format, nodes, relationships, properties, time, rows, batchSize, batches, done, data
RETURN file, source, format, nodes, relationships, properties, time, rows, batchSize, batches, done, data
---
CALL apoc.cypher.runTimeboxed("", {}, 2000000);



      Delayed::Worker.logger.info("finished query, writing records")

      filename = if @query.record?
                   TraitBank::RecordDownloadWriter.new(hashes, @base_filename, @url).write
                 elsif @query.taxa?
                   TraitBank::PageDownloadWriter.write(hashes, @base_filename, @url)
                 else
                   raise "unsupported result type"
                 end

      Delayed::Worker.logger.info("finished data download")
      filename
    end
  end
end
