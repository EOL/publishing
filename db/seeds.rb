# Added by Refinery CMS Pages extension
Refinery::Pages::Engine.load_seed

if Page.exists?(1149380)
  OccurrenceMap.create(page_id: 1149380, url: 'https://demo.gbif.org/species/5331532')
end

# --
def fix_common_names(scientific, common)

  nodes = Node.where(scientific_name: scientific)
  return nil if nodes.count == 0
  node = nodes.first

  page = Page.where(id: node.page_id).first_or_create do |p|
    p.id = node.page_id
    p.native_node_id = node.id
  end

  nodes.each do |plant|
    cmn = Vernacular.where(string: common, node_id: node.id,
      page_id: page.id, language_id: Language.english.id).first_or_create do |n|
        n.string = common
        n.node_id = node.id
        n.page_id = page.id
        n.language_id = Language.english.id
        n.is_preferred = true
        n.is_preferred_by_resource = true
      end
    node.vernaculars << cmn
  end
end

fix_common_names("Plantae", "plants")
fix_common_names("Animalia", "animals")

[CollectionAssociation, Node, PageContent, ScientificName, Vernacular].
  each do |k|
    k.counter_culture_fix_counts
  end

Rank.fill_in_missing_treat_as
