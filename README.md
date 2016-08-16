# eol_website
This repository contains rails code for the new version of EOL (TRAMEA).

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


