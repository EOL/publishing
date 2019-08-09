class ScientificName < ActiveRecord::Base
  belongs_to :node, inverse_of: :scientific_names
  belongs_to :resource, inverse_of: :scientific_names
  belongs_to :taxonomic_status, inverse_of: :scientific_names
  # DENORMALIZED:
  belongs_to :page, inverse_of: :scientific_names

  scope :preferred, -> { where(is_preferred: true) }
  scope :synonym, -> { where(is_preferred: false) }

  counter_culture :page

  DISPLAY_STATUS_PREFERRED_VALUES = Set.new(["accepted", "preferred"])

  # We discovered that about 40 resources were affected by a bug where the #scientific_name attribute of a Node could be
  # assigned to a non-preferred ScientificName. This code detects those problems and heals them.
  def self.fix_bad_node_names
    nodes_healed = {}
    # the taxonomic_status_id is never nil. I checked. There is no provisionally accepted, but there is "accepted",
    # which is ... unexpected (I didn't think that would be "published"). We'll have to figure those out.
    good_tax_stat_ids = TaxonomicStatus.where(name: ['preferred', 'accepted']).pluck(:id)
    #  459, 452 <- WoRMS, and PaleoDB: had a problem with duplicates. We may be able to check is_preferred in this case, though.
    affected_resource_ids = [395, 406, 469, 471, 474, 484, 504, 507, 562, 563, 565, 570, 581, 583, 584, 588,
      595, 601, 621, 624, 625, 628, 629, 631, 634, 639, 640, 644, 647, 652, 651, 648, 654, 667, 687, 695, 726]
    bad_names = ScientificName.includes(:node).joins(:node).
      where(['scientific_names.resource_id IN (?) AND scientific_names.taxonomic_status_id IN (?) AND '\
        'nodes.canonical_form != scientific_names.canonical_form', affected_resource_ids, good_tax_stat_ids]); 1
    count = bad_names.count
    begin
      bad_names.find_each do |name|
        if nodes_healed.key?(name.node_id)
          raise "ERROR: Trying to fix node = Node.find(#{name.node_id}) twice, second time for name2 = ScientificName.find(#{name.id}), first time for name1 = ScientificName.find(#{nodes_healed[name.node_id]})"
        end
        name.node.update_attributes(canonical_form: name.canonical_form, scientific_name: name.verbatim)
        nodes_healed[name.node_id] = name.id
        c = nodes_healed.keys.count
        if (c % 1000).zero?
          puts "*" * 100
          pct = (c / count.to_f * 100).round(2)
          puts "Have healed #{c} Nodes, about #{pct}% complete."
        end
      end
      # Now we have to fix all of the is_preffered values, which may or may not be right (it looks like a 50/50 chance
      # from some early poking at the DB).
      ScientificName.joins(:node).
        where(['scientific_names.resource_id IN (?) AND scientific_names.is_preferred = ? AND '\
          'nodes.canonical_form != scientific_names.canonical_form', affected_resource_ids, true]).update_all(is_preferred: false)
      ScientificName.joins(:node).
        where(['scientific_names.resource_id IN (?) AND scientific_names.is_preferred = ? AND '\
          'nodes.canonical_form = scientific_names.canonical_form', affected_resource_ids, false]).update_all(is_preferred: true)
    ensure
      puts "++ Healed #{nodes_healed.keys.count} nodes."
    end
  end

  # scientific_names.id >= 17100001
  def self.re_de_normalize_page_ids(scope = nil)
    scope ||= '1=1' # ALL
    min = where(scope).minimum(:id)
    max = where(scope).maximum(:id)
    # This can be quite large, as this is a relatively fast query. (Note it's a big table, so this still requires a long
    # time OVERALL.)
    batch_size = 50_000
    while min < max
      where(scope).joins(:node).
        where(['nodes.page_id IS NOT NULL AND scientific_names.id >= ? AND scientific_names.id < ?', min, min + batch_size]).
        update_all('scientific_names.page_id = nodes.page_id')
      min += batch_size
    end
  end

  def <=>(other)
    italicized <=> other.italicized
  end

  def display_status
    if taxonomic_status == TaxonomicStatus.unusable
      :unusable
    elsif DISPLAY_STATUS_PREFERRED_VALUES.include?(taxonomic_status.name)
      :preferred
    else
      :alternative
    end
  end
end
