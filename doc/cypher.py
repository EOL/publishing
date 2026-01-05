#!/usr/bin/python3

# This is an example API client program.  It invokes the `cypher`
# service with parameters supplied on the command line.  Actual use of
# the API could be as simple as the central HTTP request, which can be
# done with wget or curl, or as complex as a translation to your
# favorite programming language, as a module to be used in a larger
# program.

# To get this to work you may have to do the following, or equivalent:
#   sudo apt-get install python3-pip
#   sudo pip3 install requests

import requests, argparse, json, sys

default_server = "https://beta.eol.org"
sample_data = {"a": "has space", "b": "has %", "c": "has &"}

def doit(server, api_token, query, format, unsafe):
    url = "%s/service/cypher" % server.rstrip('/')
    if format == None: format = "cypher"
    data = {"query": query, "format": format}
    headers = {"accept": "application/json",
               "authorization": "JWT " + api_token}
    if unsafe:
      r = requests.post(url,
                        stream=(format=="csv"),
                        headers=headers,
                        params=data)
    else:
      r = requests.get(url,
                       stream=(format=="csv"),
                       headers=headers,
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
            print(r.text[0:1000], file=sys.stderr)
            sys.exit(1)
        json.dump(j, sys.stdout, indent=2, sort_keys=True)
        print('\n')
    elif ct == "text/csv":
        # https://stackoverflow.com/questions/16694907/how-to-download-large-file-in-python-with-requests-py#16696317
        for line in r.iter_lines(): 
            if line: # filter out keep-alive new lines
                try:
                    print(line.decode('utf-8'))
                except UnicodeDecodeError as err:
                    sys.stderr.write('Decoding trouble: %s\n%s\n' % (err, chunk))
    elif ct == "text/plain":
        print(r.text, file=sys.stderr)
    else:
        sys.stderr.write('Unrecognized response content-type: %s\n' % ct)
        print(r.text[0:10000], file=sys.stderr)
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
    parser.add_argument('--unsafe', help='set to true if an unsafe operation (DELETE etc)', default=False)
    args=parser.parse_args()
    query = args.query
    if args.queryfile != None:
        with open(args.queryfile, 'r') as infile:
            query = infile.read().strip()
    token = args.token
    if args.tokenfile != None:
        with open(args.tokenfile, 'r') as infile:
            token = infile.read().strip()
    doit(args.server, token, query, args.format, args.unsafe)
