raise "You have nothing in your database" unless Article.count > 0
raise "Youy have no articles linked to pages" if Article.last.pages.empty?
page = Article.last.pages.first
raise "You need a page that has both an article and an image" unless
  page.media.count > 0
puts "Attaching references to page #{page.id}"

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

[CollectionAssociation, Node, PageContent, ScientificName, Vernacular].
  each do |k|
    k.counter_culture_fix_counts
  end
