# eol_website
This repository contains rails code for the new version of EOL (TRAMEA).

[![Build Status](https://travis-ci.org/EOL/eol_website.svg?branch=master)](https://travis-ci.org/EOL/eol_website)
[![Coverage
Status](https://coveralls.io/repos/github/EOL/eol_website/badge.svg?branch=master)](https://coveralls.io/github/EOL/eol_website?branch=master)
[![Code Climate](https://codeclimate.com/github/EOL/eol_website/badges/gpa.svg)](https://codeclimate.com/github/EOL/eol_website)

## Up and Running

You should install the following before proceeding:
* MySQL or MariaDB
* Neo4j
    * `brew install neo4j`
    * `brew services start neo4j` (or just `neo4j start` if you don't want it always running)
    * visit `http://localhost:7474/browser/`
    * login with neo4j:neo4j
    * change your password as directed, e.g.: YOURNEWPASSWORD
    * `rails runner "TraitBank::Admin.setup"`
* ElasticSearch (`brew install elasticsearch`)

Before getting far, you should install ElasticSearch:
```bash
brew install elasticsearch   # Mac OS X
sudo dpkg -i elasticsearch-[version].deb  # Ubuntu
```

## More information

There is various additional information about the project in the doc/ folder.
