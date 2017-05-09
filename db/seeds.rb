# Added by Refinery CMS Pages extension
Refinery::Pages::Engine.load_seed

if Page.exists?(1149380)
  OccurrenceMap.create(page_id: 1149380, url: 'https://demo.gbif.org/species/5331532')
end

# --

if plants = Node.where(scientific_name: "Plantae")
  plant = plants.first

  plant_page = Page.where(id: plant.page_id).first_or_create do |p|
    p.id = plant.page_id
    p.native_node_id = plant.id
  end

  plants.each do |plant|
    cmn = Vernacular.where(string: "plants", node_id: plant.id,
      page_id: plant_page.id, language_id: Language.english.id).first_or_create do |n|
        n.string = "plants"
        n.node_id = plant.id
        n.page_id = plant_page.id
        n.language_id = Language.english.id
        n.is_preferred = true
        n.is_preferred_by_resource = true
      end
    plant.vernaculars << cmn
  end
end

# --

if animals = Node.where(scientific_name: "Animalia")
  animal = animals.first

  animal_page = Page.where(id: animal.page_id).first_or_create do |p|
    p.id = animal.page_id
    p.native_node_id = animal.id
  end

  animals.each do |animal|
    cmn = Vernacular.where(string: "animals", node_id: animal.id,
      page_id: animal_page.id, language_id: Language.english.id).first_or_create do |n|
        n.string = "animals"
        n.node_id = animal.id
        n.page_id = animal_page.id
        n.language_id = Language.english.id
        n.is_preferred = true
        n.is_preferred_by_resource = true
      end
    animal.vernaculars << cmn
  end
end

[CollectionAssociation, Node, PageContent, ScientificName, Vernacular].
  each do |k|
    k.counter_culture_fix_counts
  end

Rank.fill_in_missing_treat_as
