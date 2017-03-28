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

rails r "Import::Page.from_file(%Q{#{Rails.root}/doc/store-14706.json})"
rails r "Import::Page.from_file(%Q{#{Rails.root}/doc/store-14709.json})"
rails r "Import::Page.from_file(%Q{#{Rails.root}/doc/store-328598.json})"

# __OPTIONALLY, and, of course, you want to use your own source dir__
rails r "Import::Clade.from_file('/Users/jrice/t/store-clade-1642-part132.json')"

rake db:seed

bundle exec rake sunspot:reindex
```
