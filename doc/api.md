# About the web services API

The web services API is in its infancy.  Suggestions welcome.

## Authorization

In order for you to be able to use the web services API, an EOL
administrator needs to make you a "power user" by doing the following:

    rails r 'User.find_by_email("you@you.you").grant_power_user'

where you@you.you is the email address for your account on the EOL
site. Please contact hammockj AT si.edu

## Getting a token

The API can be used directly in a browser, but to use it from a
program (including a shell script) it is necessary to obtain a
'token'.  This is simply a string that holds encrypted information
that tells the web services who you are.

For now, you need to get a token using a web browser; later you'll be
able to do this from a script.

To obtain a token, visit the page
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

## Example query: show traits

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
