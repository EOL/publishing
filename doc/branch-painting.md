# Branch painting

'Branch painting' is the process of adding of trait assertions to the
graph database that are inferred by propagating selected traits through the
taxonomic hierarchy.  An inferred trait assertion is represented as
an `:inferred_trait` relationship between a Page node and a Trait
node, very similar in form to a `:trait` relationship.

## Preparing a resource file

Branch painting is driven by 'start' and 'stop' directives associated
with traits in the relevant resource.  Directives are represented as
MetaData nodes attached to the Trait node that is to be 'painted'.  A
'start' directive says that branch painting should be initiated at the
Page given in the directive (its `measurement`), propagating to
descendant taxa, while a 'stop' directive says that branch painting
for this trait should not continue apply to the given node or its
descendants.

Typically a Trait node will have one start directive and any number of
stop directives that are descendants of the start directive.  The page
given in the start node will be the same as the page associated with
the trait.  However, the start node could be any node at all, and
there could even be multiple start nodes.

Often the stop directive for one trait will be a start node for
another trait.  That is, the second trait "overrides" the first.

Start directive MetaData nodes have a predicate of
https://eol.org/schema/terms/starts_at.  Stop directives have a
predicate of 
https://eol.org/schema/terms/stops_at.

## Using the branch painting script

The branch painting script (in [lib/painter.rb](../lib/painter.rb))
implements a suite of operations related to branch painting.

* `count` - count a resource's inferred trait assertions
* `qc` - run a series of quality control queries to identify problems
  with the resource's directives
* `infer` - determine a resource's inferred trait assertions (based on
  directives), and write them to a file
* `merge` - read inferred trait assertions from file (see `infer`) and
  add them to the graphdb
* `clean` - remove all of a resource's inferred trait assertions
* `directives` - lists all of a resource's branch painting directives
  (a directive is a 'start' or 'stop' metadata node)

The choice of command, and any parameters, are communicated via
shell variables.  Shell variables can be set using `export` or
using the bash syntax `variable=value command`.

The shell variables / parameters are:

* `COMMAND` - a command, see list above
* `SERVER` - the http server for an EOL web app instance, used for its
  cypher service.  E.g. `https://eol.org/`.  Default is `https://beta.eol.org/`.
* `TOKEN` - API token to be used with `SERVER`
* `RESOURCE` - the resource id of the resource to be painted
* `STAGE_SCP_LOCATION` - remote staging directory, written in a form to be
    used with an `scp`
    command, where temporary files are to be stored; looks like
    `hostname:directory/` 
* `STAGE_WEB_LOCATION`  - the same directory, written in a form for
    access via HTTP; looks like `http://hostname/directory/`

For example:

    export SERVER="https://beta.eol.org/"
    export TOKEN=`cat ~/Sync/eol/beta.token`
    export STAGE_SCP_LOCATION="varela:public_html/tmp/"
    export STAGE_WEB_LOCATION="http://varela.csail.mit.edu/~jar/tmp/"

    RESOURCE=640 COMMAND=qc ruby -r ./lib/painter.rb -e Painter.main

The ordinary sequence of operations would be:

 1. Obtain a production admin token using https://eol.org/services/authenticate
    (see API documentation)
 2. Publish a new version of the resource
 3. Clear the cache from any previous painting run,
    since otherwise the `infer` command will be lazy and assume that
    cached results (from the previous version of the resource) are still
    correct.  Do `rm -rf infer-NNN` where NNN is the resource id.
 4. `COMMAND=count` - if the count is 0, that probably means
    that the resource has been recently republished and it is time to
    proceed with branch painting.  It could also mean that the
    resource id is incorrect.  If the count is nonzero, then the resource has
    been previously painted, but has not been updated since, so go
    back and make sure you've published the new version.
 5. `COMMAND=qc` - run quality control checks on the directives, looking for ill-formed
    ones (those referring to missing pages and so on).
 6. `COMMAND=infer` - write the inferred relationships to an `infer-NNN`
    directory, where NNN is the resource id.
 7. `COMMAND=merge` - store the inferred relationships into the graphdb.

If you have both admin and non-admin tokens, you might run all but the
last command using the non-admin token, out of an abundance of caution.

Branch painting generates a lot of logging output.  If you have a
local web application instance you might want to add `config.log_level = :warn` to
`config/environments/development.rb` to reduce noise emitted to
console.
