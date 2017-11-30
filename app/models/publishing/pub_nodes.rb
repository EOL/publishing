class Publishing::PubNodes
  attr_reader :node_id_by_page
  def self.import(resource, log, repo)
    Publishing::PubMedia.new(resource, log, repo).import
  end

  def initialize(resource, log, repo)
    @resource = resource
    @log = log
    @repo = repo
    @node_pks = []
    @identifiers = []
    @ancestors = []
    @node_id_by_page = {}
  end

  def import
    @log.log('import_nodes')

    count = @repo.get_new(Node) do |node|
      node_pk = node[:resource_pk]
      @node_pks << node_pk
      rank = node.delete(:rank)
      identifiers = node.delete(:identifiers)
      # Keeping these for posterity: I had altered the JSON output of the API and needed to parse out the sciname:
      # sname = node.delete(:scientific_name)
      # node[:scientific_name] = sname['normalized'] || sname['verbatim']
      # node[:canonical_form] = sname['canonical'] || sname['verbatim']
      @identifiers += identifiers.map { |ident| { identifier: ident, node_resource_pk: node_pk } }
      # TODO: move this to a hash-cache thingie... (mind the downcase)
      unless rank.nil?
        rank = Rank.where(name: rank).first_or_create do |r|
          r.name = rank.downcase
          r.treat_as = Rank.guess_treat_as(rank)
        end
        node[:rank_id] = rank.id
      end
      if (ancestors = node.delete(:ancestors))
        ancestors.each_with_index do |anc, depth|
          next if anc == node_pk
          @ancestors << { node_resource_pk: node_pk, ancestor_resource_pk: anc,
                          resource_id: @resource.id, depth: depth }
        end
      end
      # TODO: we should have the repository calculate the depth...
      # So, until we parse the WHOLE thing (at the source), we have to deal with this. Probably fair enough to include
      # it here anyway:
      node[:canonical_form] = "Unamed clade #{node[:resource_pk]}" if node[:canonical_form].blank?
      node[:scientific_name] = node[:canonical_form] if node[:scientific_name].blank?
      # We do store the landmark ID, but this is helpful.
      node[:has_breadcrumb] = node.key?(:landmark) && node[:landmark] != "no_landmark"
      node[:landmark] = Node.landmarks[node[:landmark]]
    end
    return [] if count.zero?
    # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
    # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
    @identifiers.in_groups_of(10_000, false) do |group|
      Identifier.import(group, on_duplicate_key_ignore: true, validate: false)
    end
    @ancestors.in_groups_of(10_000, false) do |group|
      NodeAncestor.import(group, on_duplicate_key_ignore: true, validate: false)
    end
    Node.propagate_id(resource: @resource, fk: 'parent_resource_pk', other: 'nodes.resource_pk',
                      set: 'parent_id', with: 'id', resource_id: @resource.id)
    Identifier.propagate_id(resource: @resource, fk: 'node_resource_pk', other: 'nodes.resource_pk',
                            set: 'node_id', with: 'id', resource_id: @resource.id)
    NodeAncestor.propagate_id(resource: @resource, fk: 'ancestor_resource_pk', other: 'nodes.resource_pk',
                              set: 'ancestor_id', with: 'id', resource_id: @resource.id)
    NodeAncestor.propagate_id(resource: @resource, fk: 'node_resource_pk', other: 'nodes.resource_pk',
                              set: 'node_id', with: 'id', resource_id: @resource.id)
    create_new_pages
    @node_id_by_page.keys || []
  end

  def create_new_pages
    @log.log('create_new_pages')
    # CREATE NEW PAGES: TODO: we need to recognize DWH and allow it to have its pages assign the native_node_id to it,
    # regardless of other nodes. (Meaning: if a resource creates a weird page, the DWH later recognizes it and assigns
    # itself to that page, then the native_node_id should *change* to the DWH id.)
    have_pages = []
    @node_pks.in_groups_of(1000, false) do |group|
      page_ids = []
      Node.where(resource_pk: group).select("id, page_id").find_each do |node|
        @node_id_by_page[node.page_id] = node.id
        page_ids << node.page_id
      end
      have_pages += Page.where(id: page_ids).pluck(:id)
    end
    missing = @node_id_by_page.keys - have_pages
    pages = missing.map { |id| { id: id, native_node_id: @node_id_by_page[id], nodes_count: 1 } }
    if pages.empty?
      @log.log('There were NO new pages, skipping...', cat: :warns)
      return
    end
    pages.in_groups_of(1000, false) do |group|
      @log.log("importing #{group.size} Pages", cat: :infos)
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      Page.import!(group, on_duplicate_key_ignore: true)
    end
    @log.log('fixing counter_culture counts for Node...')
    Node.where(resource_id: @resource.id).counter_culture_fix_counts
  end
end
