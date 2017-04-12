raise "You have nothing in your database" unless Article.count > 0
raise "Youy have no articles linked to pages" if Article.last.pages.empty?
page = Article.last.pages.first
raise "You need a page that has both an article and an image" unless
  page.media.count > 0
puts "Attaching references to page #{page.id}"

def add_sections_to_articles
  [
    { id: 1, parent_id: 0, name: "overview", position: 1 },
    { id: 2, parent_id: 1, name: "brief_summary", position: 2 },
    { id: 3, parent_id: 0, name: "physical_description", position: 5 },
    { id: 4, parent_id: 0, name: "ecology", position: 203 },
    { id: 6, parent_id: 0, name: "relevance_to_humans_and_ecosystems", position: 270 },
    { id: 8, parent_id: 0, name: "conservation", position: 264 },
    { id: 41, parent_id: 4, name: "habitat", position: 204 },
    { id: 218, parent_id: 4, name: "dispersal", position: 206 },
    { id: 242, parent_id: 4, name: "general_ecology", position: 211 },
    { id: 251, parent_id: 6, name: "benefits", position: 271 },
    { id: 267, parent_id: 3, name: "morphology", position: 6 },
    { id: 285, parent_id: 4, name: "associations", position: 208 },
    { id: 286, parent_id: 8, name: "conservation_status", position: 265 },
    { id: 293, parent_id: 3, name: "diagnostic_description", position: 8 },
    { id: 296, parent_id: 8, name: "management", position: 269 },
    { id: 300, parent_id: 0, name: "wikipedia", position: 291 },
    { id: 303, parent_id: 0, name: "names_and_taxonomy", position: 320 },
    { id: 308, parent_id: 1, name: "comprehensive_description", position: 3 },
    { id: 309, parent_id: 1, name: "distribution", position: 4 },
    { id: 313, parent_id: 4, name: "diseases_and_parasites", position: 209 },
    { id: 315, parent_id: 0, name: "life_history_and_behavior", position: 234 },
    { id: 317, parent_id: 315, name: "cyclicity", position: 236 },
    { id: 320, parent_id: 315, name: "reproduction", position: 239 },
    { id: 321, parent_id: 315, name: "growth", position: 240 },
    { id: 326, parent_id: 0, name: "molecular_biology_and_genetics", position: 258 },
    { id: 329, parent_id: 326, name: "genetics", position: 259 },
    { id: 333, parent_id: 326, name: "molecular_biology", position: 263 },
    { id: 336, parent_id: 0, name: "notes", position: 292 },
    { id: 347, parent_id: 303, name: "taxonomy", position: 324 }
  ].each do |hash|
    Section.where(id: hash[:id]).first_or_create do |s|
      s.id = hash[:id]
      s.parent_id = hash[:parent_id]
      s_name = hash[:name]
    end
  end

  secs = Section.all
  Article.includes(:sections).find_each do |art|
    art.sections << secs.shuffle.first if art.sections.empty?
    art.save!
  end
end

def add_referent(body, page, parents)
  ref = Referent.where(body: body).first_or_create do |r|
    r.body = body
  end
  page.referents << ref
  Array(parents).compact.each do |parent|
    Reference.create(parent: parent, referent: ref)
  end
end

add_referent(%Q{Govaerts R. (ed). For a full list of reviewers see: <a href="http://apps.kew.org/wcsp/compilersReviewers.do">http://apps.kew.org/wcsp/compilersReviewers.do</a> (2015). WCSP: World Checklist of Selected Plant Families (version Sep 2014). In: Species 2000 & ITIS Catalogue of Life, 26th August 2015 (Roskov Y., Abucay L., Orrell T., Nicolson D., Kunze T., Flann C., Bailly N., Kirk P., Bourgoin T., DeWalt R.E., Decock W., De Wever A., eds). Digital resource at <a href="http://www.catalogueoflife.org/col">www.catalogueoflife.org/col</a>. Species 2000: Naturalis, Leiden, the Netherlands. ISSN 2405-8858.}, page, page.media.first)

add_referent(%Q{L. 1753. In: Sp. Pl. : 982}, page, page.nodes.first)

add_referent(%Q{Marticorena C & R Rodríguez . 1995-2005. Flora de Chile. Vols 1, 2(1-3). Ed. Universidad de Concepción, Concepción. 351 pp., 99 pp., 93 pp., 128 pp. Matthei O. 1995. Manual de las malezas que crecen en Chile. Alfabeta Impresores. 545 p.}, page, [page.articles.first, page.media.last])
# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

# Added by Refinery CMS Pages extension
Refinery::Pages::Engine.load_seed

if Page.exists?(1149380)
  OccurrenceMap.create(page_id: 1149380, url: 'https://demo.gbif.org/species/5331532')
end

# --

plants = Node.where(scientific_name: "Plantae")
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

# --

animals = Node.where(scientific_name: "Animalia")
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

add_sections_to_articles

[CollectionAssociation, Node, PageContent, ScientificName, Vernacular].
  each do |k|
    k.counter_culture_fix_counts
  end
