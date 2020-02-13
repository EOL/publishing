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

### OS X Details

As of Jan 28th, in my own environment (Mojave), this was enough to get the code
running:

brew update && brew upgrade ruby-build
brew install openssl
Add the following to your ~/.bash_profile as needed:

  export PATH="/usr/local/opt/openssl@1.1/bin:$PATH"
  eval "$(rbenv init -)"
  export LDFLAGS="-L/usr/local/opt/readline/lib -L/usr/local/opt/openssl@1.1/lib"
  export CPPFLAGS="-I/usr/local/opt/readline/include -I/usr/local/opt/openssl@1.1/include"
  export PKG_CONFIG_PATH="/usr/local/opt/readline/lib/pkgconfig"
  export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"
  export GEM_HOME=$HOME/.gem

You may have to do this (I did) if you are coming from an older verison of gem:

gem sources -r http://gems.rubyforge.org/
gem sources -r http://gems.github.com
gem sources -a https://rubygems.org/

You may just want tp update bundler, but I (perhaps stupidly) uninstalled it,
then:

gem install bundler

Them, making sure you have sourced your bash profile and cd'ed to the project
directory:

rbenv install
cd .
bundle

...That was it, I was up and running.

## More information

There is various additional information about the project in the doc/ folder.
