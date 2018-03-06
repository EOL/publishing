# Resetting (for development)

## IF THIS IS YOUR FIRST TIME

It should be safe to re-run this if you're not sure, but you won't want to keep
doing this every time you load data into neo4j; particularly when it starts to
fill up.

```bash
rails r "TraitBank::Admin.setup"
```

## Every Other Time

We should probably eventually add this to seeds, but for the moment, you can do
this:

```bash
rake db:reset
rails r "TraitBank::Admin.nuclear_option! && Rails.cache.clear"

# NOTE: We currently have a HUUUUUUGE problem: there's not a great way to load your database with good test data. We
# will address this as soon as we can, but it's not presently a priority! Apologies. Please talk to a team member about
# a less-than-perfect way to get started.

rake stats:score_richness

rake searchkick:reindex:all

# Why isn't this working after the import? It should. :S  Perhaps it needs to reindex first?
rails r "PageIcon.fix"
```
