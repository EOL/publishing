class Import::Repository
  def self.sync
    # TODO.
  end

    # The website would periodically request harvests from the repository:
    #   repository = RepositoryApi.new
    #   per_page = 1000
    #   deltas = {}
    #   tables = [:pages, :nodes, :scientific_names, :media, :traits, :etc]
    #   types = [:new, :changed, :removed]
    #   # TODO: first we need to communicate which resources are available, so we get new resources,
    #   resources = repository.diffs_since?(RepositorySync.last.created_at)
    #   sync = RepositorySync.new  # more details later
    #   resources.each do |resource|
    #     repository.resource_diffs_since?(resource, RepositorySync.last.created_at).each do |diff|
    #       tables.each do |table|
    #         types.each do |type|
    #           next unless diff[table][type] &&
    #                       diff[table][type].to_i > 0
    #           page = 1
    #           have = 0
    #           while have < diff[table][type]
    #             # TODO: this would be a different call, using a URL like
    #             # repository.eol.org/resources/1/nodes.json?since=1484321785&type=new&page=1&per=1000
    #             response = repository.get_diff_deltas(resource_id: resource.id,
    #               since: RepositorySync.last.created_at, table: table, type: type,
    #               page: page, per: per_page)
    #             # TODO: error-handling
    #             deltas[table][type] += response[table]
    #             have += response.size
    #             page += 1
    #             last if response[:no_more_items]
    #           end
    #         end
    #       end
    #     end
    #     tables.each do |table|
    #       types.each do |type|
    #         # I didn't sketch out these types. Some of them would be moderately
    #         # complex, since they need to denormalize things, and the :media table
    #         # would be broken up into subtables, etc...
    #         call(:"bulk_#{type}", deltas[table][type])
    #       end
    #     end
    #   end
    #
    #   # This implies a response structure to "diffs_since" a bit like this:
    #   {
    #     # NOTE: no pages. Just send nodes; the client will resolve the page_ids itself. This includes removed nodes; the
    #     # client will look up the nodes and remove them; if the associated page is then empty, it will remove the page.
    #     nodes: {
    #       new: 27,
    #       changed: 0,
    #       removed: 0 },
    #     scientific_names: {
    #       new: 256,
    #       changed: 0,
    #       removed: 12 },
    #     media: {
    #       new: 103,
    #       changed: 12,
    #       removed: 6 },
    #     etc: 'etc'
    #   }
    #
    #   # And then a response structure to get_diff_deltas something like this, assuming the params were resource_id: 1, since:
    #   # "2017-01-13 10:36:25", table: "nodes", type: "new" page: 1, per: 1000 e.g.:
    #   # repository.eol.org/resources/1/nodes.json?since=1484321785&type=new      optionally: &page=1&per=1000
    #   {
    #     nodes: [
    #       { "repository_id"=>603,
    #         "page_id"=>1115346,
    #         "rank"=>"species",
    #         "parent_repository_id"=>602,
    #         "scientific_name"=>"<i>Echinochloa crus-galli</i> (L.) P. Beauv.",
    #         "canonical_form"=>"<i>Echinochloa crus-galli</i>",
    #         "resource_pk"=>"9786302",
    #         "source_url"=>
    #           "http://www.catalogueoflife.org/annual-checklist/details/species/id/9786302" }
    #     ],
    #     no_more_items: "true"
    #   }
    #   # And for type: "removed"
    #   {
    #     nodes: [
    #       { "resource_pk"=>"9786302" }
    #     ],
    #     no_more_items: "true"
    #   }
    #   # And for type "changed" ... note that this allows the SITE to do
    #   # reconciliation with curations (which occurred on that site)
    #   {
    #     nodes: [
    #       { "resource_pk"=>"9786302",
    #         "repository_id"=>927845,
    #         "source_url"=> "http://www.catalogueoflife.org/annual-checklist/species/id/9786302" }
    #     ],
    #     no_more_items: "true"
    #   }
    #
    #   # WE ARE IGNORING CURATION FOR NOW. It will be a significant question about how
    #   # we handle it: we could either let the sites manage their own curation, so
    #   # everyone is an island, or we could send all curation back to the harvesting
    #   # repository. Or something in between (say, ignoring curatorial edits, or
    #   # ignoring everything except node curation, etc). Thoughts required.
    #
    #   class Node
    #     def needs_to_be_mapped?
    #       return true if page_id.blank?
    #       return true if scientific_name.changed?
    #       return true if is_virus.changed?
    #       return true if in_unmapped_area?
    #     end
    #
    #     def matched_ancestor(depth)
    #       i = 0
    #       ancestors.each do |ancestor|
    #         unless ancestor.page_id.nil?
    #           return ancestor if i >= depth
    #           i += 1
    #         end
    #       end
    #     end
    #   end
    #
    #   # TODO: think about what happens if the DWH changes "Animalia" and gets
    #   # reharvested?
    #
    #   #
    #   # Name Matching
    #   #
    #
    #   # What should be stored in a speedy index... I'm writing the queries in
    #   # pseudo-SQL syntax for brevity/portability:
    #   index: {
    #     pages: {
    #       scientific_name: "(ACTUALLY NOT! This is really canonical + authority and NOTHING ELSE. And only those preferred by DWH)",
    #       synonyms: "(synonyms from DWH)",
    #       other_synonyms: "(from all sources)",
    #       canonical_name: "(from DWH)",
    #       canonical_synonyms: "(from DWH)",
    #       other_canonical_synonyms: "(from all sources)",
    #       ancestor_ids: "ordered (proximal to root), from DWH",
    #       other_ancestor_ids: "(from other hierarchies)",
    #       children: "(names, from DWH)", # ... I am not sure we want/need this in the index, but we'll need to get it, and be mindful of performance.
    #       is_hybrid: "identified either explicitly during import or by gnparser" } }
    #
    #   # some variables which are assumed to be defined:
    #   @resource = "the resource that is being harvested"
    #   @harvest = "some record of the harvest event itself"
    #   @index = "some kind of connection to the index"
    #   root_nodes = "all of the nodes from the resource; stored as a nested "\
    #     "hierarchy; this variable references the root nodes, which we'll walk down"
    #   # Method names, in the order in which they should be attempted:
    #   @strategies = [
    #     # TODO: we might want to add an initial check to see if there are lots of
    #     # ancestors / children, since in those cases, they might provide a better
    #     # match.
    #     { attribute: :scientific_name, index: :scientific_name, table: :eq },
    #     { attribute: :scientific_name, index: :synonyms, table: :in },
    #     { attribute: :scientific_name, index: :other_synonyms, table: :in },
    #     { attribute: :canonical_name, index: :canonical_name, table: :eq },
    #     { attribute: :canonical_name, index: :canonical_synonyms, table: :in },
    #     { attribute: :canonical_name, index: :other_canonical_synonyms, table: :in }
    #   ]
    #
    #   # We want the search to be as fast as possible
    #   # Unmatched names are expensive (so we really want to limit them)
    #
    #   # Mmmmmaybe we could do an early check (after the firtst failure?) to see if the
    #   # name is there AT ALL... and stop if it's not.
    #
    #   @first_non_scientific_strategy_index =
    #     @strategies.index { |s| s[:attribute] != :scientific_name }
    #   # Constants like these really should be CONFIGURABLE, not hard-coded, so we can
    #   # change a text file on the server and re-run something to try new values.
    #   @child_match_weight = 1 # We will want this for tweaking, over time...
    #   @ancestor_match_weight = 1 # Ditto...
    #   @max_ancestor_depth = 2 # We would like to be able to change this...
    #   # If fewer (or equal to) this many ancestors match, then we assume this is just
    #   # a bad match (and we never allow it), regardless of how much "better" it might
    #   # look than others due to sheer numbers.
    #   @minimum_ancestry_match_pct = 0.2
    #
    #   map_all_nodes_to_pages(root_nodes)
    #
    #   # The algorithm, as pseudo-code (Ruby, for brevity):
    #   def map_all_nodes_to_pages(root_nodes)
    #     @harvest.log_mapping_started
    #     map_nodes(root_nodes)
    #     @harvest.log_mapping_completed
    #   end
    #
    #   def map_nodes(nodes)
    #     nodes.each do |node|
    #       map_if_needed(node)
    #     end
    #   end
    #
    #   def map_if_needed(node)
    #     if node.needs_to_be_mapped?
    #       strategy = 0
    #       # Skip scientific name searches if all we have is a canonical (really)
    #       strategy = @first_non_scientific_strategy_index if ! node.has_authority?
    #       map_node(node, ancestor_depth: 0, strategy: 0)
    #     end
    #     map_nodes(node.children) if node.children.any?
    #   end
    #
    #   def map_node(node, opts = {})
    #     # NOTE: Surrogates never get matched in this version of the algorithm.
    #     return unmapped(node) if node.is_surrogate?
    #     # NOTE: Node.native_virus returns the "Virus" node in the DWH. NOTE: If the
    #     # node has been flagged (by gnparser) as a virus, then it may ONLY match other
    #     # viruses.
    #     ancestor = if node.is_virus?
    #       Node.native_virus
    #     else
    #       # NOTE: #matched_ancestor walks up the node's ancestors and returns the Nth #
    #       # non-nil page, or nil if none.
    #       node.matched_ancestor(opts[:ancestor_depth])
    #     end
    #     map_unflagged_node(node, ancestor, opts)
    #   end
    #
    #   # *** SKIP THESE:
    #   #
    #   # q = "canonical_name = 'Chordata' AND ancestor_ids INCLUDES 1"
    #   #
    #   # page =
    #   # {
    #   #   id: 1
    #   #   node_ids: [ 1, 11, ... ]
    #   #   canonical_name: ["Animalia"]
    #   #   ...
    #   #   ancestors: []
    #   # },
    #   # {
    #   #   id: 2
    #   #   node_ids: [ 2, 12, ... ]
    #   #   canonical_name: ["Choradata"]
    #   #   ...
    #   #   ancestors: [1]
    #   # },
    #   # {
    #   #   id: 5
    #   #   node_ids: [ 5, 15, ... ]
    #   #   ancestors: [1, 2, 3, 4]
    #   #   canonical_name: ["Procyonidae"]
    #   # }
    #   #
    #   # @index =
    #   #   pages
    #   #     {
    #   #       page_id: 1
    #   #       scientific_name: ["Animalia"]
    #   #       synonyms: ["adsfl;ghjkasdl;f", "dsfgsdfg"],
    #   #       other_synonyms: ["sdfg sdfg", "sdfgsdfgz"]
    #   #       ...
    #   #     }
    #   #
    #   # Resource = Dynamic Working Hierarchy
    #   # 1 "Animalia" page_id = 1
    #   #   2 "Chordata" page_id = 2
    #   #     3 "Mammalia" page_id = 3
    #   #       4 "Carnivora" page_id = 4
    #   #         5 "Procyonidae" page_id = 5
    #   #           6 "Procyon" page_id = 6
    #   #             7 "Procyon lotor" page_id = 7
    #   #   2345 "Morus alba" page_id = 43563
    #   # 234 "Plantae"
    #   #   90863 "Morus alba" page_id = 934573
    #   #
    #   #
    #   # Resource = Foobar *NEW*
    #   # 11 "Animalia" = page_id = 1
    #   #   12 "Chordata" = page_id = 2
    #   #     13 "Mammalia" = page_id = 3
    #   #       14 "Carnivora" = page_id = 4
    #   #         15 "Procyonidae" = page_id = 5
    #   #          18 "Procyonidillia"  = page_id == nil  UNMAPPED
    #   #           16 "Procyon" = page_id = 6
    #   #             17 "Procyon lotor" = page_id = nil
    #   #
    #   # Rersource = "Flickr"  *NEW*
    #   #   "Morus alba"
    #   #
    #   #
    #   # *** SKIP THOSE ^
    #
    #   # TODO: this name is not accurate; change.
    #   def map_unflagged_node(node, ancestor, opts)
    #     q = build_search_query(node, ancestor, opts)
    #     results = @index.pages.where(q)
    #     if results.size == 1
    #       return node.map_to_page(results.first["page_id"])
    #     elsif results.size > 1
    #       return more_than_one_match(node, results)
    #     else # no results found! Tweak the options and try again, if possible.
    #       opts[:strategy] ||= 0
    #       opts[:strategy] += 1
    #       # TODO: mmmmmaybe we want to do a sanity check here and abort if the name is
    #       # just NOT in the database at all, and NOT go through all of the strategies.
    #
    #       # TODO: MMmmmmmaybe we want a counter (across the whole resource) that, once
    #       # it crosses some threshold of unmapped names (OR some limit on time),
    #       # notifies someone. That will let us know that a resource is having trouble
    #       # and someone can choose to stop it or consider things.
    #
    #       if @strategies[opts[:strategy]].nil?
    #         opts[:strategy] = @first_non_scientific_strategy_index
    #         opts[:ancestor_depth] ||= 0
    #         opts[:ancestor_depth] += 1
    #         if opts[:ancestor_depth] > @max_ancestor_depth
    #           # Too far! We must stop:
    #           return unmapped(node, opts)
    #         end
    #       end
    #       map_unflagged_node(node, ancestor, opts) # NOTE: recursion
    #     end
    #   end
    #
    #   def more_than_one_match(node, matching_pages)
    #     scores = {}
    #     matching_pages.each do |matching_page|
    #       scores[matching_page] = {}
    #       # NOTE: #child_names will have to get the (let's go with canonical) names of
    #       # all the children. NOTE: #count_matches does exactly what it implies:
    #       # counts the number of (exactly the same) strings.
    #       scores[matching_page][:matching_children] =
    #         count_matches(matching_page.child_names, node.child_names)
    #       scores[matching_page][:matching_ancestors] =
    #         # NOTE: this is idiomatic ruby for "count the number of ancestors with
    #         # page_ids assigned":
    #         node.ancestors.select { |a| ! a.page_id.nil? }.size
    #       # NOTE: we are unsure of how effective this is; we really need to pay
    #       # attention to how this performs.
    #       if scores[matching_page][:matching_ancestors] <=
    #          ( node.ancestors.size * @minimum_ancestry_match_pct )
    #         scores[matching_page][:matching_ancestors] = 0
    #         # This is just a warning, since it won't match, but might be worth
    #         # investigating, since it's *possible* we're skipping a better match.
    #         @harvest.log_insufficient_ancestry_matches(node, matching_page)
    #       else
    #         scores[matching_page][:score] =
    #           scores[matching_page][:matching_children] * @child_match_weight +
    #           scores[matching_page][:matching_ancestors] * @ancestor_match_weight
    #       end
    #     end
    #     best_match = nil
    #     best_score = 0
    #     scores.each do |page, details|
    #       if details[:score] > best_score
    #         best_match = page
    #         best_score = details[:score]
    #       end
    #     end
    #     node.map_to_page(best_match["page_id"])
    #     # TODO: if all of the scores are 0, it's not a match, skip it.
    #     # TODO: if two of the scores share the best match, it's not a match, skip it. ...but log that!
    #     @harvest.log_multiple_matches(node, scores)
    #   end
    #
    #   def build_search_query(node, ancestor, opts)
    #     strategy = @strategies[opts[:strategy]]
    #     q = strategy[:index].to_s
    #     # TODO: in Solr I think this really just becomes ":" in BOTH cases...
    #     q += strategy[:table] == :in ? " INCLUDES " : " = "
    #     q += "'#{node.send(strategy[:attribute])}'" # TODO: proper quoting, of course.
    #     # NOTE: we do NOT check ancestry for scientific names! We assume these will
    #     # match across all of life, with few exceptions.
    #     if ancestor && strategy[:attribute] != :scientific_name
    #       q += if opts[:other_ancestors]
    #         " AND (other_ancestor_ids INCLUDES "\
    #           "#{ancestor.page.node_ids.join(" OR other_ancestor_ids INCLUDES ")})"
    #       else
    #         " AND ancestor_ids INCLUDES #{ancestor.page.native_node.id}"
    #       end
    #     end
    #     q += " AND is_hybrid = True" if node.is_hybrid?
    #   end
    #
    #   def unmapped(node, opts = {})
    #     node.create_new_page
    #     @harvest.log_unmapped_node(node, opts)
    #   end
    # end

    # rake db:reset ; rails runner "Import::Repository.work_in_prog"
  def self.work_in_prog
    instance = self.new
    instance.work_in_prog
  end

  def work_in_prog
    node_id_by_page = {}
    # TODO: sync the resource (and content partner) itself.
    # TEMP:
    partner = Partner.find(1)
    resource = Resource.find(1)

    Node.where(resource_id: resource.id).delete_all # TEMP!!!

    nodes = get_new_instances_from_repo(Node, resource) do |node|
      rank = node.delete(:rank)
      unless rank.nil?
        rank = Rank.where(name: rank).first_or_create do |r|
          r.name = rank
          r.treat_as = Rank.guess_treat_as(rank)
        end
        node[:rank_id] = rank.id
      end
      # TODO: we should have the repository calculate the depth...
      # So, until we parse the WHOLE thing (at the source), we have to deal with this. Probably fair enough to include
      # it here anyway:
      node[:scientific_name] ||= "Unamed clade #{node[:resource_pk]}"
      node[:canonical_form] ||= "Unamed clade #{node[:resource_pk]}"
    end
    Node.import(nodes)
    # TODO: calculate lft and rgt... Ick.
    propagate_id(Node, resource: resource, fk: 'parent_resource_pk',  other: 'nodes.resource_pk',
                       set: 'parent_id', with: 'id')
    Node.counter_culture_fix_counts
    # CREATE NEW PAGES: TODO: we need to recognize DWH and allow it to have its pages assign the native_node_id to it,
    # regardless of other nodes.
    begin
      Node.where(resource_pk: nodes.map { |n| n.resource_pk }).select("id, page_id").find_each do |node|
        node_id_by_page[node.page_id] = node.id
      end
      have_pages = Page.where(id: node_id_by_page.keys).pluck(:id)
      missing = node_id_by_page.keys - have_pages
      pages = missing.map { |id| { id: id, native_node_id: node_id_by_page[id], nodes_count: 1 } }
      Page.import!(pages)
    rescue => e
      debugger
      puts "normal?"
    end

    ScientificName.where(resource_id: resource.id).delete_all # TEMP!!!

    names = get_new_instances_from_repo(ScientificName, resource) do |name|
      status = name.delete(:taxonomic_status)
      status = "accepted" if status.blank?
      unless status.nil?
        name[:taxonomic_status_id] = TaxonomicStatus.find_or_create_by(name: status).id
      end
      name[:node_id] = 0 # This will be replaced, but it cannot be nil. :(
    end
    begin
      ScientificName.import(names)
      propagate_id(ScientificName, resource: resource, fk: 'node_resource_pk',  other: 'nodes.resource_pk',
                         set: 'node_id', with: 'id')
      # TODO: This doesn't ensure we're getting *preferred* scientific_name.
      propagate_id(Node, resource: resource, fk: 'id',  other: 'scientific_names.node_id',
                         set: 'scientific_name', with: 'italicized')
    rescue => e
      debugger
      puts "hi"
    end

    ScientificName.counter_culture_fix_counts
    Page.reindex
    Node.rebuild!(false) # TODO: can we run this on a single resource?!?
    # This takes about 1 minute for each 1K pages. ...Too long for me to wait during tests:
    # Reindexer.score_richness_for_pages(Page.where(id: node_id_by_page.keys))
  end

  def get_new_instances_from_repo(klass, resource)
    type = klass.class_name.underscore.pluralize.downcase
    things = []
    page = 1
    total_pages = 2 # Dones't matter YET... will be populated in a bit...
    while page <= total_pages
      url = "http://localhost:3000/resources/#{resource.repository_id}/#{type}.json?page=#{page}"
      puts "<< #{url}"
      html_response = Net::HTTP.get(URI.parse(url))
      response = JSON.parse(html_response)
      total_pages = response["totalPages"]
      response[type.camelize(:lower)].each do |thing_data|
        thing = {}
        thing_data.each { |k, v| thing[k.underscore.to_sym] = v }
        yield(thing)
        things << klass.new(thing.merge(resource_id: resource.id))
      end
      page += 1
    end
    things
  end

  # I AM NOT A FAN OF SQL... but this is **way** more efficient than alternatives:
  def propagate_id(klass, options = {})
    fk = options[:fk]
    set = options[:set]
    resource = options[:resource]
    with_field = options[:with]
    (o_table, o_field) = options[:other].split(".")
    sql = "UPDATE `#{klass.table_name}` t JOIN `#{o_table}` o ON (t.`#{fk}` = o.`#{o_field}` AND t.resource_id = ?) "\
          "SET t.`#{set}` = o.`#{with_field}`"
    clean_execute(klass, [sql, resource.id])
  end

  def clean_execute(klass, args)
    clean_sql = klass.send(:sanitize_sql, args)
    klass.connection.execute(clean_sql)
  end
end
