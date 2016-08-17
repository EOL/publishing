rake db:reset ; rails c
  TraitBank.nuclear_option!
  Import::Page.from_file("http://beta.eol.org/store-328598.json")
  Import::Page.from_file("http://beta.eol.org/store-19831.json")
  exit
bundle exec rake sunspot:reindex
