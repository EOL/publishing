# Solr

## Reindexing

If at any point you wish to reindex what you have in the database, run:
```bash
bundle exec rake sunspot:reindex
```
## Error: 'Exception writing document ... possible analysis error.'

I couldn't figure out a "polite" way to fix this; I believe it has something to
do with the Solr process running too long and losing track of old instances, but
I couldn't prove that and I couldn't find a clean solition. I opted for "the
nuclear option":

```bash
ps -ef | grep solr
# Kill all of those processes (except the grep, of course)
rm -rf solr/
rm config/sunspot.yml
rails generate sunspot_rails:install
rake sunspot:solr:start
rake sunspot:reindex
```

...While drastic, this did resolve the problem. :S
