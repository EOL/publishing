#!/usr/bin/python

# This is an example API client program.  It invokes the `cypher`
# service with parameters supplied on the command line.  Actual use of
# the API could be as simple as the central HTTP request, which can be
# done with wget or curl, or as complex as a translation to your
# favorite programming language, as a module to be used in a larger
# program.

import requests, argparse, json, sys

default_server = "https://beta.eol.org"
sample_data = {"a": "has space", "b": "has %", "c": "has &"}

def doit(server, api_token, query, format):
    url = "%s/service/cypher" % server.rstrip('/')
    if format == None: format = "cypher"
    data = {"query": query, "format": format}
    r = requests.get(url,
                     stream=(format=="csv"),
                     headers={"accept": "application/json",
                              "authorization": "JWT " + api_token},
                     params=data)
    if r.status_code != 200:
        sys.stderr.write('HTTP status %s\n' % r.status_code)
    ct = r.headers.get("Content-Type").split(';')[0]
    if ct == "application/json":
        j = {}
        try:
            j = r.json()
        except ValueError:
            sys.stderr.write('JSON syntax error\n')
            print >>sys.stderr, r.text[0:1000]
            sys.exit(1)
        json.dump(j, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write('\n')
    elif ct == "text/csv":
        # https://stackoverflow.com/questions/16694907/how-to-download-large-file-in-python-with-requests-py#16696317
        for chunk in r.iter_content(chunk_size=1024): 
            if chunk: # filter out keep-alive new chunks
                sys.stdout.write(chunk)
    elif ct == "text/plain":
        print >>sys.stderr, r.text
    else:
        sys.stderr.write('Unrecognized response content-type: %s\n' % ct)
        print >>sys.stderr, r.text[0:1000]
        sys.exit(1)
    if r.status_code != 200:
        sys.exit(1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--token', help='API token', default=None)
    parser.add_argument('--tokenfile', help='file containing bare API token', default=None)
    parser.add_argument('--query', help='cypher query to run', default=None)
    parser.add_argument('--queryfile', help='file containing cypher query to run', default=None)
    parser.add_argument('--server', help='URL for EOL web app server', default=default_server)
    parser.add_argument('--format', help='result format (json or csv)', default=None)
    args=parser.parse_args()
    query = args.query
    if args.queryfile != None:
        with open(args.queryfile, 'r') as infile:
            query = infile.read().strip()
    token = args.token
    if args.tokenfile != None:
        with open(args.tokenfile, 'r') as infile:
            token = infile.read().strip()
    doit(args.server, token, query, args.format)
