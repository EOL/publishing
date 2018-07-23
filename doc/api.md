# About the web services API

## Authorization

In order for you to be able to use the web services API, an EOL
administrator needs to do the following:

    rails r 'User.find_by_email("you@you.you").grant_power_user'

where you@you.you is the email address for your account on the EOL site. Please contact hammockj AT si.edu

## Getting a token

You need to get a token using the ordinary UI in the browser; later
you'll be able to do this from a script.  

The page to visit, after you log in, is called
https://beta.eol.org/services/authenticate.  Copy the token
(without the quotes) from the web browser into a file, so you can use
it in API calls.  Keep the token in a safe place; it is similar to a
password.

## Invoking API methods

The services are under `/service/`.  Currently the only service is `/service/cypher`.

Services are invoked using HTTP, either from a browser, using a
command line tool such as `curl` or `wget`, or a library such as
`requests` in python.

With each request, it is necessary to provide the token in an HTTP
`Authorization:` header, for example:

    Authorization: JWT eyJ0eXAzczOzJZUzZ1NzJ9.eyJ1c2VyZjoTA1QWJsZzfQ.Xf5FSA2P_lJBGyBYGTsRPczAkg

Don't forget to use `https:` instead of `http:`, to keep the token private.

## Example: Access using curl

[to be written]

## Example: Access using python

Here is a simple python program that invokes the `/service/cypher` API
call.  The name of the file containins the token is given as a command
line argument, and the query is given as a second command line
argument.

```
#!/usr/bin/python

import requests, argparse, json, sys

sample_data = {"a": "has space", "b": "has %", "c": "has &"}

def doit(tokenfile, query):
    with open(tokenfile, 'r') as infile:
        api_token = infile.read()
    url = "http://127.0.0.1:3000/service/cypher"
    data = {"query": query}
    sys.stderr.write("url = %s\n" % url)
    r = requests.get(url,
                     headers={"accept": "application/json",
                              "authorization": "JWT " + api_token},
                     params=data)
    sys.stderr.write("full url = %s\n" % r.url)
    json.dump(r.json(), sys.stdout, indent=2)
    sys.stdout.write('\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--tokenfile', help='file containing bare API token', default=None)
    parser.add_argument('--query', help='cypher query to run', default=None)
    args=parser.parse_args()

    doit(args.tokenfile, args.query)
```

## Example query: show traits

[to be written]
