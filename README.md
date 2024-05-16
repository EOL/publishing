# publishing
This repository contains rails code for the new version of EOL (TRAMEA).

[![Build Status](https://travis-ci.org/EOL/publishing.svg?branch=master)](https://travis-ci.org/EOL/publishing)
[![Coverage
Status](https://coveralls.io/repos/github/EOL/publishing/badge.svg?branch=master)](https://coveralls.io/github/EOL/publishing?branch=master)
[![Code Climate](https://codeclimate.com/github/EOL/publishing/badges/gpa.svg)](https://codeclimate.com/github/EOL/publishing)

## Up and Running on OS X:

These instructions are very much out of date and are likely incomplete. If you
happen to need to go through this process again, please help us update it!

I would skip installing MySQL, Neo4j, ElasticSearch, or Redis. Just use the docker
containers for those things.

```
brew update && brew upgrade ruby-build
brew install openssl
brew install michael-simons/homebrew-seabolt/seabolt
brew install node yarn
```

You may have to do this (I did) if you are coming from an older verison of gem:

```
gem sources -r http://gems.rubyforge.org/
gem sources -r http://gems.github.com
gem sources -a https://rubygems.org/
```

You may just want tp update bundler, but I (perhaps stupidly) uninstalled it,
then `gem install bundler`

Then, install rvm using [whatever method they ask you to](https://rvm.io/rvm/install),
it changes. :\

Make sure you have sourced your bash profile and cd'ed to the project directory, then:

```
rvm install <whatever version of Ruby is in .ruby-version>
cd .
bundle
```

## Up and Running on Debian 11

* Install RVM
* use RVM to install the correct version of ruby (in root .ruby-version file)
* update bundler to whatever version is in the Gemfile.lock
* update apt-get
* install nodejs with apt-get
* run `bundle`
* compile and install seabolt, following the commands in Dockerfile.eol_seabolt_rails

...That's pretty much it, assuming you run everything else in containers!

## More information

There is various additional information about the project in the doc/ folder.
