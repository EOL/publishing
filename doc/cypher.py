#!/usr/bin/python

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
