# This is NOT meant to serve as permanent documentation. It's simply a file for
# thoughts about the design, in the form of pseudo-code.

### TAXON PAGE:
# "Common Raccoon"
page.common_name.titlize
# "Procyon lotor" (this will be in itals on the page)
page.canonical_form
# NOTE: I'm not including routes, but we would have links to each of these TAXON PAGEs:
# "Animal", "Mammal", "Carnivoran", "Coatis, Raccoons, and Relatives"
page.ancestors.exemplar.each { |a| a.common_name.titlize ; a.rank }
# The main image, large
image = page.image
image.src(:large)
### The main images' metadata...
# The image title:
image.title
# The "bar" styled logo:
image.license.logo(:bar)
# "Some rights reserved"
image.license.statement
# "Phototographer: <a href='something'>Arthur Chapman</a>", "Location created: Ontario, Canada", "(c) Arthur Chapman", "Supplier: <a href='...'>Flickr EOL Images</a>"
image.attributions.each { |attr| attr.string.html_safe }
# The site where it came from:
image.source_url
# The full-size link:
image.src(:full)
### End of image metadata
page.media.count
page.articles.count
page.maps.count
page.traits.count
page.literature_references.count
page.names.count
# "The Common Raccoon is a mammal in the family Procyonidae.  It is an omnivore
# and inhabits a variety of terrestrial and aquatic habitats in North and
# Central America."
page.auto_summary
page.traits.exemplar.each do |trait|
  # NOTE: I'm not including routes, but this would have a link to a PREDICATE PAGE:
  # e.g.: "circadian rhythm"
  trait.predicate.name
  # e.g.: ["average"]
  trait.predicate.modifiers.each { |mod| mod.name }
  # NOTE: I'm not including routes, but this would have a link to a VALUE PAGE:
  # e.g.: "nocturnal/crepuscular"
  trait.value.name
  # e.g.: "mm"
  trait.value.units.name
  # e.g.: ["adult"]
  trait.value.modifiers.each { |mod| mod.name }
end
# The occurence/range map:
page.map

page.related_pages.each do |rel_page|
  # "Crabbicus generica"
  rel_page.scientific_name
  # "Some Kind of Crab"
  rel_page.common_name
  # "Animal", "Arthropod", "Shrimps, Crabs, Lobsters, Water Fleas, and Relatives", "Rock Crabs"
  rel_page.ancestors.exemplar.each { |a| a.common_name.titlize ; a.rank }
  # Square image:
  rel_page.image.src(:icon)
end
page.related_collections
# Related links are ... complicated. They may include things like Podcasts,
# Audio files, RSS Feeds, Maps, Articles, Food Webs, iNat maps, Websites (of
# various types: Wikipedia, Citizen Science resources, Literature / Papers, and
# more)... and probably others. We need to talk about these...
page.related_links.each do |link|
  # "Podcast"
  link.type
  # "EOL Podcast: Coral Reefs"
  link.name
  # square icon
  link.src(:icon)
  # ":audio"
  link.link_type
  # "http://podcasts.eol.org/A67D220EE"
  link.src
  # "Coral reefs are bustling cities of marine life, until rising ocean
  # temperatures turn them into ghost towns. Can reefs spring back from
  # devastating bleaching events?"
  link.summary.html_safe
  # ["audio_player.js"] (maybe... making this one up)
  link.includes
end

### PREDICATE PAGE
if filters[:page]
  page = filters[:page]
  # "Common Raccoon"
  page.common_name
  # "Procyon lotor"
  page.canonical_form
  # "Animal", "Mammal", "Carnivoran", "Coatis, Raccoons, and Relatives"
  page.ancestors.exemplar.each { |a| a.common_name.titlize ; a.rank }
end
filters.each do |type, value|
  # e.g.: "Taxon"
  I18n.t("traits.filters.types.#{type}")
  # e.g.: "Any"
  I18n.t("traits.filters.values.any")
end
# "circadian rhythm"
predicate.name
# NOTE: this would actually be broken up into groups by value name, on the page:
traits.each do |trait|
  # "Animal", "Mammal", "Carnivoran", "Coatis, Raccoons, and Relatives"
  trait.page.ancestors.exemplar.each { |a| a.common_name.titlize ; a.rank }
  # "Procyon lotor"
  trait.page.canonical_form
  # "Common Raccoon"
  trait.page.common_name
  # Square icon of the species:
  page.image.src(:icon)
  # ["adult"]
  trait.predicate.modifiers.each { |mod| mod.name }
  # "nocturnal/crepuscular"
  trait.value.name
  # "PanTHERIA"
  trait.source.name
  # "http://eol.org/resources/1234"
  trait.source.url
  trait.meta.each do |meta_trait|
    # e.g.: "source"
    trait.value.name
    # e.g.: "PanTHERIA"
    trait.source.name
  end
end
