# Resetting (for development)

## IF THIS IS YOUR FIRST TIME

It should be safe to re-run this if you're not sure, but you won't want to keep
doing this every time you load data into neo4j; particularly when it starts to
fill up.

```bash
rails r "TraitBank.setup"
```

## Every Other Time

We should probably eventually add this to seeds, but for the moment, you can do
this:

```bash
rake db:reset
rails r "TraitBank.nuclear_option! "

rails r "Import::Page.from_file('http://beta.eol.org/store-328598.json') ; Import::Page.from_file('http://beta.eol.org/store-19831.json')"
# __OR__
rails r "Import::Clade.from_file('http://beta.eol.org/store-7665-clade.json')"
# If you have Betula nigra (1149380) imported, you can use its map:
rails r "OccurrenceMap.create(page_id: 1149380, url: 'https://demo.gbif.org/species/5331532')"

bundle exec rake sunspot:reindex
```
