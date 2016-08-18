# Resetting (for development)

We should probably eventually add this to seeds, but for the moment, you can do
this:

```bash
rake db:reset
rails r "TraitBank.nuclear_option! ; Import::Page.from_file('http://beta.eol.org/store-328598.json') ; Import::Page.from_file('http://beta.eol.org/store-19831.json')"
bundle exec rake sunspot:reindex
```
