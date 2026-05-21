# About the web services API

This EOL v3 web services API is in its infancy.  Suggestions welcome.

## Authorization

In order for you to be able to use the web services API, an EOL
administrator needs to create a token for you. Please contact hammockj AT si.edu

The token is simply a string that holds encrypted information
that tells the web services who you are.

## Invoking API methods

Individual API services all have URLs starting `https://eol.org/service/` (singular).

Services are invoked using HTTPS.

With each request, it is necessary to provide the token in an HTTP
`Authorization:` header, preceded by `JWT`.  For example:

    Authorization: JWT eyJ0eXAzczOzJZUzZ1NzJ9.eyJ1c2VyZjoTA1QWJsZzfQ.Xf5FSA2P_lJBGyBYGTsRPczAkg

Don't forget to use `https:` instead of `http:`, to keep the token private.

The manner in which you specify the addition of this header depends on
the programming language.  For examples see below.

If you store the token in a file, be sure to protect the file.  On any
Unix-like machine, you can do the following at the shell: (assume the
file is called `api.token`)

    chmod 600 api.token

Services can be used whenever an HTTPS client is available, e.g. from
a web browser, using a command line tool such as `curl` or `wget`, or
a library such as `requests` in python.  See [the documentation on
using the API from various platforms](api-access.md) for a few
examples.

## The `cypher` service

Currently (November 2018) the only API service is `/service/cypher`.
This service takes the following parameters via the usual CGI
key=value convention.

 - `query` - a Cypher query (see [here](https://neo4j.com/docs/developer-manual/current/cypher/))
 - `format` - requests a particular output format

Two output formats are available:

 - `cypher` (the default) - the JSON format natively returned by the neo4j Cypher query engine
 - `csv` - comma separated values format, with a header row naming the returned variables listed in the query, and each subsequent row being a result record

A number of examples of queries against the traits database are
[provided](query-examples.md).
These example queries illustrate both the use of Cypher (the query
language) and the use of the traits database [schema](trait-schema.md).


## Restrictions

* A LIMIT clause is required, in order to encourage you to put a cap on
  result set sizes (remember that small errors in a query might lead to 
  enormous query result sets)
* Queries (commands) that would cause changes to the graph database
  are rejected: create, set, delete, and so on
  
## Quirks

* cypher is case sensitive, and URIs from many of our terms sources 
habitually include uppercase letters. Be aware that your patterns must 
match case.

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
