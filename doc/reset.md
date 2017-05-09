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

# Assuming you have a copy of the clade-7665.json clade file available:
rails r "Import::Clade.read(%Q{clade-7665.json})"

rake db:seed
rake stats:score_richness

bundle exec rake sunspot:reindex
```
