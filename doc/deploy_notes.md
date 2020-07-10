= MESSAGES TO A FUTURE SELF

== Explanation

...Please include here any information you might want a developer to know, when
they upgrade and deploy the code. Examples include notes about migrations that
are required, scripts that need to be run after the update, suggestions about
features to double-check once they are in production, or even reminders to ping
a specific developer or manager once the code is updated.

Messages that have been acted upon will be removed from this document (they will
persist in git histories, of course).

Thanks.

== THE NOTES:

6/3/2020 (mvitale): db:migrate && bundle required for deploy of changes from branch bye\_refinery (in master)
6/15/2020 (mvitale): Add neo4jrb_url (bolt://...:7687) to secrets.yml. Data download code also metadata migration to have been performed, but will still run if not.
6/18 (jrice): I am upgrading Elasticsearch to 6.8 (from 6.6). This requires a cluster restart.
6/23 (mvitale): autocomplete changes that require Page and TermNode to be reindexed. TermNode can be reindexed in a console using `TermNode.reindex` ...it only takes about 10 minutes.
6/24 (mvitale): For webpacker assets: install Node 10.17.0+ & Yarn 1.x+. bundle install && yarn install. Webpack assets should be automatically compiled in the assets:precompile task; ping me if not.

=== Deployed 2020-07-02

* NOTE: I came back to this on Jul 10 to run `MetaMover.run_all` which hadn't been done yet.

7/7/2020 (mvitale): Reindex Page and Term. For production: set config.x.autocomplete\_i18n\_enabled = false in application.rb, then set back to true once reindex is done. rake db:migrate.
