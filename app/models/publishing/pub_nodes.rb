class Publishing::PubNodes
  def self.import(resource, log, repo)
    log ||= Publishing::PubLog.new(resource)
    a_long_long_time_ago = 1202911078 # 10 years ago when this was written; no sense coding it.
    repo ||= Publishing::Repository.new(resource: resource, log: log, since: a_long_long_time_ago)
    Publishing::PubNodes.new(resource, log, repo).import
  end

  def initialize(resource, log, repo)
    @resource = resource
    @log = log
    @repo = repo
    @node_pks = []
    @identifiers = []
    @ancestors = []
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
    Node.propagate_id(fk: 'parent_resource_pk', other: 'nodes.resource_pk',
                      set: 'parent_id', with: 'id', resource_id: @resource.id)
    Identifier.propagate_id(fk: 'node_resource_pk', other: 'nodes.resource_pk',
                            set: 'node_id', with: 'id', resource_id: @resource.id)
    NodeAncestor.propagate_id(fk: 'ancestor_resource_pk', other: 'nodes.resource_pk',
                              set: 'ancestor_id', with: 'id', resource_id: @resource.id)
    NodeAncestor.propagate_id(fk: 'node_resource_pk', other: 'nodes.resource_pk',
                              set: 'node_id', with: 'id', resource_id: @resource.id)
    PageCreator.by_node_pks(@node_pks, @log)
  end
end
