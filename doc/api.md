
= About the web services API

Stub.  To be written.

You need to get a token using the ordinary UI in the browser; later
you'll be able to do this from a script.  The page to visit, after you
log in, is called `/services/authenticate`.

The services are under `/service/`.  Currently the only service is `/service/cypher`.

Here is a simple python program that does an API call (assuming the
API token has already been written to a file).

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
