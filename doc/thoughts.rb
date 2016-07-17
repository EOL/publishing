# This is NOT meant to serve as permanent documentation. It's simply a file for
# thoughts about the design, in the form of pseudo-code.

### TAXON PAGE:
# "Common Raccoon"
page.common_name.titlize
# "Procyon lotor" (this will be in itals on the page)
page.canonical_form
# NOTE: I'm not including routes, but we would have links to each of these TAXON PAGEs:
# "Animals", "Mammals", "Carnivoran", "Coatis, Raccoons, and Relatives"
page.ancestors.exemplar.each { |a| a.common_name.titlize }
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
page.featured_collections

### PREDICATE PAGE
if filters[:page]
  page = filters[:page]
  # "Common Raccoon"
  page.common_name
  # "Procyon lotor"
  page.canonical_form
  # "Animals", "Mammals", "Carnivoran", "Coatis, Raccoons, and Relatives"
  page.ancestors.exemplar.each { |a| a.common_name.titlize }
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
  # "Animals", "Mammals", "Carnivoran", "Coatis, Raccoons, and Relatives"
  trait.page.ancestors.exemplar.each { |a| a.common_name.titlize }
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
