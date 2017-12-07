class Publishing::PubScientificNames
  def self.import(resource, log, repo)
    Publishing::PubScientificNames.new(resource, log, repo).import
  end

  def initialize(resource, log, repo)
    @resource = resource
    @log = log
    @repo = repo
  end

  def import
    @log.log('import_scientific_names')
    bad_names = []
    count = @repo.get_new(ScientificName) do |name|
      status = name.delete(:taxonomic_status)
      status = "accepted" if status.blank?
      unless status.nil?
        name[:taxonomic_status_id] = get_tax_stat(status)
      end
      name[:node_id] = 0 # This will be replaced, but it cannot be nil. :(
      name[:italicized].gsub!(/, .*/, ", et al.") if name[:italicized] && name[:italicized].size > 200
      if name[:page_id].nil?
        bad_names << name[:canonical_form]
        name = nil
      end
    end
    if bad_names.size.positive?
      @log.log("** WARNING: you've got #{bad_names.size} scientific_names with no page_id!")
      bad_names.in_groups_of(20, false) do |group|
        @log.log("BAD: #{group.join('; ')}")
      end
    end
    return if count.zero?
    ScientificName.propagate_id(resource: @resource, fk: 'node_resource_pk',  other: 'nodes.resource_pk',
                       set: 'node_id', with: 'id', resource_id: @resource.id)
    # TODO: This doesn't ensure we're getting *preferred* scientific_name.
    Node.propagate_id(resource: @resource, fk: 'id',  other: 'scientific_names.node_id',
                       set: 'scientific_name', with: 'italicized', resource_id: @resource.id)
    @log.log('fixing counter_culture counts for ScientificName...')
    ScientificName.counter_culture_fix_counts
  end

  def get_tax_stat(status)
    @tax_stats ||= {}
    return @tax_stats[status] if @tax_stats.key?(status)
    @tax_stats[status] = TaxonomicStatus.find_or_create_by(name: status).id
  end
end
