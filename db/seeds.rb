# Added by Refinery CMS Pages extension
Refinery::Pages::Engine.load_seed

# --

Reindexer.fix_common_names("Plantae", "plants")
Reindexer.fix_common_names("Animalia", "animals")
Reindexer.fix_all_counter_culture_counts

Rank.fill_in_missing_treat_as

u = User.create(username: "admin", email: "admin@eol.org", password: "admin4Tramea", admin: true)
u.activate
