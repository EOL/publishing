# Dumping Traitbank

The `dump_traits` family of `rake` commands is intended to create
Traitbank dumps, which anyone can download, from the main web site or
from the opendata site (depending on how we eventually decide to
deploy them).

At present (October 2018) the scripts are driven entirely from the
neo4j graphdb.  This is based on the hypothesis that when people say
they want "all the traits", then all the information they need will be
present in the graphdb, not the MySQL database.  If they need other
tables (e.g. synonyms or vernaculars from the MySQL database), they
will be able to get them in some other way.  I don't know if this is
true; there may be more work to do here.

### `dump_traits:dump`

Purpose of this command: At the command line, generate a ZIP file dump
of the entire trait graphdb.  See the associated support module
[traits_dumper.rb](../app/support/trait_bank/traits_dumper.rb) to see
how it's implemented.

The ZIP file will contain four `.csv` files, one for each major kind
of node: pages, traits, metadata, and terms.

The command can also be used for partial dumps of particular clades.

Command parameters are passed via environment variables:

 - `ZIP`: pathname of the .zip file to be written (should include
         the terminal '.zip').  The default value comes from the `path` method
         of the `DataDownload` class, which I think
         corresponds to the URL with path `/data/downloads/`, and the filename 
         has a form similar to `traitbank_YYYYMMDD.zip`.
 - `ID`: the page id of the taxon that is the root of the subtree to
        be dumped.  Default is all life (2913056).
 - `LIMIT`: size limit for the query result sets.  You can make this a small
            number, if you're just debugging the infrastructure or queries.
            Default is big (1000000).
 - `CSVDIR`:  pathname of the directory to which the intermediate CSV 
            files will be written.  Default is a directory created
        under `/tmp` with a name starting with `traitbank_`.
        The files are not deleted at the end; the operating system will take
        care of this eventually, and in the meantime they are there
        for examination.

### `dump_traits:smoke`

This is for testing only.  Same as `dump` but defaults `ID` to 7662
(Carnivora), defaults `LIMIT` to 100, and defaults `ZIP` to a file in
the current directory.

## Testing this module

Tests to do in sequence (easier to harder):

  1. Smoke test: \
         `bundle exec rake dump_traits:smoke`
     - should write a file in the current directory whose name starts with 'traitbank_' and ends with _smoke.zip
     - size of file should be >= 7000 bytes and < 70000 bytes
     - you can delete the .zip file
  2. Carnivora:\
         `time bundle exec rake ID=7662 ZIP=test1.zip dump_traits:dump`
     - size of test1.zip should be >= 400000
     - you can delete test1.zip
  3. Vertebrates:\
         `time bundle exec rake ID=2774383 ZIP=test2.zip dump_traits:dump`
     - also tell me the size of the file
     - you can delete test1.zip
  4. All life:\
         `time bundle exec rake ZIP=test3.zip dump_traits:dump`
