# About the web services API

The web services API is in its infancy.  Suggestions welcome.

## Authorization

In order for you to be able to use the web services API, an EOL
administrator needs to make you a "power user". Please contact hammockj AT si.edu

## Getting a token

The API can be used directly in a browser, but to use it from a
program (including a shell script) it is necessary to obtain a
'token'.  This is simply a string that holds encrypted information
that tells the web services who you are.

For now, you need to get a token using a web browser; later you'll be
able to do this from a script.

To obtain a token, log in to your power user account and visit the page
[`https://beta.eol.org/services/authenticate`](https://beta.eol.org/services/authenticate).
(Note: `services` is plural here since the token applies to all of the
services.)  Copy the token (without the quotes) from the web browser
into a file, so you can use it in API calls.  Keep the token in a safe
place; it is similar to a password.

## Invoking API methods

Individual API services are all under `/service/` (singular).
Currently the only service is `/service/cypher`.

Services are invoked using HTTP, either from a browser, using a
command line tool such as `curl` or `wget`, or a library such as
`requests` in python.

With each request, it is necessary to provide the token in an HTTP
`Authorization:` header.  For example:

    Authorization: JWT eyJ0eXAzczOzJZUzZ1NzJ9.eyJ1c2VyZjoTA1QWJsZzfQ.Xf5FSA2P_lJBGyBYGTsRPczAkg

Don't forget to use `https:` instead of `http:`, to keep the token private.

The manner in which you specify the addition of this header depends on
the programming language.  For examples see below.

If you store the token in a file, be sure to protect the file.  On any
Unix-like machine, you can do the following at the shell: (assume the
file is called `api.token`)

    chmod 600 api.token

## Example: Access from shell (bash) using wget

`wget` is a common shell utility, similar to `curl`, for doing HTTP
requests.  Suppose the API token is in a file called `api.token`.  The
following illustrates use of `wget` with the `cypher` service:

    wget -O cypher.out --header "Authorization: JWT `cat api.token`" \
      https://beta.eol.org/service/cypher?query="MATCH (n:Trait) RETURN n LIMIT 1;"

Or, if the Cypher query is in a file called `query.cypher`:

    wget -O cypher.out --header "Authorization: JWT `cat api.token`" \
      https://beta.eol.org/service/cypher?query="`cat query.cypher`"

These commands may only work from `bash`, which is the shell that I
use, and the standard shell on most GNU/Linux systems.


## Access from shell using curl

When submitting a query it's necessary to convert any spaces to `%20`.
This is not something you want to do manually.  `wget` does this
automatically, but `curl` does not, as far as I can tell.  So I
recommend you use `wget` instead of `curl`.


## Example: Access using python

Here is a simple python program that invokes the `/service/cypher` API
call.  The name of the file containins the token is given as a command
line argument, and the query is given as a second command line
argument, for example (typed at the shell):

    python cypher.py --tokenfile=api.token --query="MATCH (n:Trait) RETURN n LIMIT 1;"

where [`cypher.py`](cypher.py) is the file containing the following Python script:

```
import requests, argparse, json, sys

default_server = "https://beta.eol.org"
sample_data = {"a": "has space", "b": "has %", "c": "has &"}

def doit(tokenfile, server, query):
    with open(tokenfile, 'r') as infile:
        api_token = infile.read().strip()
    url = "%s/service/cypher" % server.rstrip('/')
    data = {"query": query}
    r = requests.get(url,
                    headers={"accept": "application/json",
                             "authorization": "JWT " + api_token},
                    params=data)
    if r.status_code != 200:
        sys.stderr.write('HTTP status %s\n' % r.status_code)
    json.dump(r.json(), sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write('\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--tokenfile', help='file containing bare API token', default=None)
    parser.add_argument('--query', help='cypher query to run', default=None)
    parser.add_argument('--server', help='URL for EOL web app server', default=default_server)
    args=parser.parse_args()
    doit(args.tokenfile, args.server, args.query)
```

*Warning:* The beta.eol.org site uses TLS1.2 for connection privacy
(`https:`).  This version of TLS seems to be not fully supported in
the version of Python that is built in to MacOS 10.12 (Sierra), and
may be absent from tools of similar vintage.  If the example fails
with an SSL error, make sure you have an up to date version of openssl
(1.0.1 works, at least) and a Python that uses it.  I find this 
puzzling since TLS 1.2 was published in 2008, but I am just relaying
my experience.

## Example: access from a web form

Put the following in a file with extension `.html`, and open it in a
browser.  This mode of use does not require a token if you are logged
in to the EOL site.

```
<h1>Cypher query</h1>
<form action='https://beta.eol.org/service/cypher'>
  <textarea name='query' id='query' cols='50' rows='5'>MATCH (n:Trait) RETURN n LIMIT 1;</textarea>
  <input type='submit' />
</form>
```

## Example queries: 

The taxa and records are modeled as a graph, which is described in the [Trait Schema](https://github.com/EOL/eol_website/blob/master/doc/trait-schema.md). New Cypher users may also find neo4j's [Cypher documentation](https://neo4j.com/docs/developer-manual/current/cypher/) helpful.

## show traits

The following Cypher query shows basic information recorded in an
arbitrarily chosen set of Trait nodes.

```
MATCH (t:Trait)<-[:trait]-(p:Page),
      (t)-[:supplier]->(r:Resource),
      (t)-[:predicate]->(pred:Term)
OPTIONAL MATCH (t)-[:object_term]->(obj:Term)
OPTIONAL MATCH (t)-[:normal_units_term]->(units:Term)
OPTIONAL MATCH (lit:Term) WHERE lit.uri = t.literal
RETURN r.resource_id, t.eol_pk, t.resource_ok, t.source, p.page_id, t.scientific_name, pred.uri, pred.name,
       t.object_page_id, obj.uri, obj.name, t.normal_measurement, units.uri, units.name, t.normal_units, t.literal, lit.name
LIMIT 5
```
## show (numerical) value for this taxon for this predicate

This query shows a value and limited metadata for a specific predicate and taxon. This construction presumes you know that this predicate has numerical values. It can be called using identifiers for the taxon (the EOL identifier, corresponding to the number in the taxon page URL, eg: https://beta.eol.org/pages/328651) and trait predicate (the term URI for the predicate)

```
MATCH (t:Trait)<-[:trait]-(p:Page),
(t)-[:supplier]->(r:Resource),
(t)-[:predicate]->(pred:Term)
WHERE p.page_id = 328651 AND pred.uri = "http://purl.obolibrary.org/obo/VT_0001259"
OPTIONAL MATCH (t)-[:units_term]->(units:Term)
RETURN p.canonical, pred.name, t.measurement, units.name, r.resource_id, p.page_id, t.eol_pk, t.source
LIMIT 1
```
or using strings for the taxon name and trait predicate name (with attendant risk of homonym confusion)

```
MATCH (t:Trait)<-[:trait]-(p:Page),
(t)-[:supplier]->(r:Resource),
(t)-[:predicate]->(pred:Term)
WHERE p.canonical = "Odocoileus hemionus" AND pred.name = "body mass"
OPTIONAL MATCH (t)-[:units_term]->(units:Term)
RETURN p.canonical, pred.name, t.measurement, units.name, r.resource_id, p.page_id, t.eol_pk, t.source
LIMIT 1
```
## show (categorical) value for this taxon for this predicate

This query shows a value and limited metadata for a specific predicate and taxon. This construction presumes you know that this predicate has categorical values known to EOL by structured terms with URIs. Here is the construction using strings for the taxon name and trait predicate name (with attendant risk of homonym confusion)

```
MATCH (t:Trait)<-[:trait]-(p:Page),
(t)-[:supplier]->(r:Resource),
(t)-[:predicate]->(pred:Term)
WHERE p.canonical = "Odocoileus hemionus" AND pred.name = "ecomorphological guild"
OPTIONAL MATCH (t)-[:object_term]->(obj:Term)
RETURN p.canonical, pred.name, obj.name, r.resource_id, p.page_id, t.eol_pk, t.source
LIMIT 1
```
## show (taxa) values for this taxon for this predicate

This query shows the EOL taxa for five ecological partners associated by a specific predicate to a taxon, with limited metadata. This construction presumes you know that this predicate is for ecological interactions with other taxa. Here is the construction using strings for the taxon name and predicate name, and returning strings for the ecological partner taxon name (with attendant risk of homonym confusion)

```
MATCH (p:Page)-[:trait]->(t:Trait),
(t)-[:supplier]->(r:Resource),
(t)-[:predicate]->(pred:Term)
WHERE p.canonical = "Enhydra lutris" AND pred.name = "eats"
WITH p, pred, t, r
MATCH (p2:Page {page_id:t.object_page_id}) 
RETURN  p.canonical, pred.name, p2.canonical, r.resource_id, p.page_id, t.eol_pk, t.source
LIMIT 5
```

## Provenance

Provenance metadata can be found as properties on the trait node or as linked MetaData nodes. 

Properties: t.source, if available, is a URL provided by the data partner, pointing to the original data source. Other properties are identifiers which can be used to construct URLs. For instance, r.resource_id can be used to construct a resource url like https://beta.eol.org/resources/396. The EOL trait record URL of the form https://beta.eol.org/pages/328651/data#trait_id=R261-PK22175282 can be constructed from p.page_id and t.eol_pk.  

Nodes: Most other provenance information can be found on MetaData nodes with three predicates. Adding the following to your query will fetch one of each, if present:
```
OPTIONAL MATCH (t)-[:metadata]->(contr:MetaData)-[:predicate]->(:Term {name:"contributor"})
OPTIONAL MATCH (t)-[:metadata]->(cite:MetaData)-[:predicate]->(:Term {name:"citation"})
OPTIONAL MATCH (t)-[:metadata]->(ref:MetaData)-[:predicate]->(:Term {name:"Reference"})
RETURN contr.literal, cite.literal, ref.literal
```
Where references are present, there may be more than one; to ensure you have them all would require an additional query. Multiple contributors are also possible, but rare.

to fetch multiple references for a given trait record:

```
MATCH (t)-[:metadata]->(ref:MetaData)-[:predicate]->(:Term {name:"Reference"})
WHERE t.eol_pk = "R483-PK24828656"
RETURN ref.literal
LIMIT 5
```

## Show all categorical value terms available for this predicate 

This query shows all categorical values represented in records for a given predicate and its children. For instance, woodiness is a child of growth habit, so categorical values for records with a predicate of woodiness will also be found by this query.

```
MATCH (t0:Trait)-[:predicate]->(p0:Term)-[:parent_term|:synonym_of*0..]->(tp0:Term)
WHERE tp0.uri = "http://eol.org/schema/terms/growthHabit"
OPTIONAL MATCH (t0)-[:object_term]->(object_term:Term)
RETURN DISTINCT object_term.name, object_term.uri
LIMIT 50;
```

## Restrictions

* A LIMIT clause is required, in order to encourage you to put a cap on
  result set sizes (remember that small errors in a query can lead to 
  enormous query result sets)
* Queries (commands) that would cause changes to the graph database
  are rejected: create, set, delete, and so on


## Installation

This section is for those managing the EOL web site itself.  Users of
the API need not be concerned about this.

To enable token authentication, one must add a single line to the
`config/secrets.yml` to set the `json_web_token_secret`.
In my own (JAR's) debugging setup I do this under the `development:`
section of the file by adding a line

    json_web_token_secret: e949a...

For other installations it might have to go under a different section.
I don't know how the key should be generated; I used a random
64-hex-digit string but maybe it doesn't have to be hex or so long.

Any change to this key will require 'power users' to get new tokens.
