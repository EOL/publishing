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

...You will need to define the following ENV variables (e.g.: export VAR=val):
```bash
EOL_TRAITBANK_URL=http://username:password@localhost:7474
EOL_DEVEL_DB_USERNAME=username
EOL_DEVEL_DB_PASSWORD=password
```

Before getting far, you should start solr:
```bash
bundle exec rake sunspot:solr:start
```

## More information

There is various addtional information about the project in the doc/ folder.
