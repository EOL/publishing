# Added by Refinery CMS Pages extension
Refinery::Pages::Engine.load_seed

# --

Reindexer.fix_common_names("Plantae", "plants")
Reindexer.fix_common_names("Animalia", "animals")
Reindexer.fix_all_counter_culture_counts

Rank.fill_in_missing_treat_as

# forces creates:
Rails.cache.clear
License.public_domain
Language.english

u = User.create(username: "admin", email: "admin@eol.org", password: "admin4Tramea", admin: true)
u.activate
user = User.create(email: "foo2@bar.com", username: "cigarman", name: "Sigmond Freud", password: "foobarbaz")
user = User.create(email: "foo3@bar.com", username: "sweaver", name: "Sigourney Weaver", password: "foobarbaz")
user = User.create(email: "foo@bar.com", username: "david", name: "David Attenboro", password: "foobarbaz")

c = Collection.create(id: 1, name: "Featured Collections", description: "Items in this collection will be featured on the homepage.")
c.users << u

partner = Partner.create(name: "Encyclopedia of Life", short_name: "EOL", description: "You know it.", homepage_url: "https://eol.org", repository_id: 1)
Resource.create(name: "EOL Dynamic Hierarchy", abbr: "DWH", description: "The 'consensus' tree of life.", partner_id: partner.id, repository_id: 1)

TraitBank::Admin.remove_all_data_leave_terms

# rake db:reset ; rails runner "Import::Repository.start(10.years.ago)"  <-- requies the harvesting server is running, sooo...
