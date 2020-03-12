# Dumping Traitbank

The traits dump script is used in either of two ways: as a ruby script
invoked from the shell (does not use rails or the webapp), or as a `rake`
command.  Both forms take their arguments via environment variables:

 - `ZIP`: pathname of the .zip file to be written (should include
         the terminal '.zip').
 - `ID`: the page id of the taxon that is the root of the subtree to
        be dumped.  Default is the entire traitbank.
 - `CHUNK`: number of records in each 'chunk' to be fetched.
            Values up to 20000 are pretty safe.
            Larger values lead to a bit of extra latency and larger result 
            sets, and possibly more timeouts.
 - `TEMP`: where to put intermediate files (defaults to a directory under `/tmp`)

The script may fail due to neo4j and/or web server timeouts (about a
minute as of this writing).  In considering the risk of a timeout,
note that the run time of each chunked query depends on both the
number of results (`CHUNK`) and the time required by `SKIP` (which is
related to the number of trait nodes per predicate, and can be quite
large, e.g. for the `Present` predicate).  The time required for a
`SKIP` could be several minutes.

At present (February 2019) the script is driven entirely from the
neo4j graphdb.  This is based on the hypothesis that when people say
they want "all the traits", then all the information they need will be
present in the graphdb, not the MySQL database.  If they need other
tables (e.g. synonyms or vernaculars from the MySQL database), they
will need to get them in some other way.  There may be more work to do
here.

See the associated support module
[traits_dumper.rb](../lib/traits_dumper.rb) for
further documentation and to see how it's implemented.

## From the shell using HTTP and the API

The default zip file destination (`ZIP`) has a form similar to
`traitbank_TAG_YYYYMM.zip` where `TAG` in the pathname is
the page id (`ID`) or `all`.

For this mode, there are two additional environment variables:

 - `SERVER`: must end with `/`.  The EOL server to contact for the requests.
   Default `https://eol.org/`.
 - `TOKEN`: a 'power user' API token.

E.g.

    export SERVER=https://eol.org/
    export TOKEN=  ... your 'power user' API token ...
    export CHUNK=50000
    ruby -r ./lib/traits_dumper.rb -e TraitsDumper.main

For the record, the following command comleted successfully on
varela.csail.mit.edu on 29 May 2019:

    TEMP=/wd/tmp/all_201905 CHUNK=10000 TOKEN=`cat ~/a/eol/api.token` time \
      ruby -r ./lib/traits_dumper.rb -e TraitsDumper.main

`TEMP` is redirected because the default `/tmp/...` is on a file
system lacking adequate space for this task.  `CHUNK` is set to 10000
because an earlier run with `CHUNK=20000` failed with a timeout.

## Via `rake` using neography

The default zip path (`ZIP`) is formed from the directory returned by
the `path` method of the `DataDownload` class, which I believe
corresponds to the web site URL with path `/data/downloads/`, and the
filename as described above, giving the clade (when specified) and
current month.

### `dump_traits:dump`

Generates a ZIP file dump of the entire traitbank graphdb.

### `dump_traits:smoke`

This is for testing only.  Same as `dump` but defaults `ID` to 7674
(Felidae) and `CHUNK` to 1000.

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
