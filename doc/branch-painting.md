# Branch painting

'Branch painting' is the process of adding of trait assertions to the
graph database that are inferred by propagating traits through the
taxonomic hierarchy.  An inferred trait assertion is represented as
an `:inferred_trait` relationship between a Page node and a Trait
node, very similar to a `:trait` relationship.

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

## Using the branch painting script

The branch painting script (in [lib/painter.rb ../lib/painter.rb])
implements a suite of operations related to branch painting.

* `directives` - lists all of a resource's branch painting directives
  (a directive is a 'start' or 'stop' metadata node)
* `qc` - run a series of quality control queries to identify problems
  with the resource's directives
* `infer` - determine a resource's inferred trait assertions (based on
  directives), and write them to a file
* `merge` - read inferred trait assertions from file (see `infer`) and
  add them to the graphdb
* `count` - count a resource's inferred trait assertions
* `clean` - remove all of a resource's inferred trait assertions

The choice of command, and any parameters, are communicated via
shell variables.  Shell variables can be set using `export` or
using the bash syntax `variable=value command`.

The shell variables / parameters are:

* `COMMAND` - a command, see list above
* `SERVER` - the http server for an EOL web app instance, used for its
  cypher service.  E.g. `"https://eol.org/"`
* `TOKEN` - API token to be used with `SERVER`
* `RESOURCE` - the resource id of the resource to be painted

For example:

    export SERVER="http://127.0.0.1:3000/"
    export TOKEN=`cat ~/Sync/eol/admin.token`

    RESOURCE=640 COMMAND=qc ruby -r ./lib/painter.rb -e Painter.main

Branch painting generates a lot of logging output.  If you have a
local instance you might want to add `config.log_level = :warn` to
`config/environments/development.rb` to reduce noise emitted to
console.
