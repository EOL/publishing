require 'csv'

namespace :terms do
  desc "Make parent/child relationships between terms, reading the data from opendata (JR's method, "\
    "includes synonyms and units)"
  task fetch: :environment do
    log = []
    count = TraitBank::Terms::Relationships.fetch_parent_child_relationships(log)
    puts "Loaded #{count} parent/child relationships."
    count = TraitBank::Terms::Relationships.fetch_synonyms(log)
    puts "Loaded #{count} synonym relationships."
    count = TraitBank::Terms::Relationships.fetch_units(log)
    puts "Loaded #{count} predicate/unit relationships. Log:"
    log.each { |l| puts(l) }
  end

  desc 'Make synonym relationships between terms (ONLY), reading the data from opendata'
  task synonyms: :environment do
    log = []
    count = TraitBank::Terms::Relationships.fetch_synonyms(log)
    puts "Loaded #{count} synonym relationships. Log:"
    log.each { |l| puts(l) }
  end

  desc 'Make unit relationships between terms (ONLY), reading the data from opendata'
  task units: :environment do
    log = []
    count = TraitBank::Terms::Relationships.fetch_units(log)
    puts "Loaded #{count} predicate/unit relationships. Log:"
    log.each { |l| puts(l) }
  end

  # NOTE: (from JR) ...oops. I didn't know this existed when I wrote Terms::Relationships. This is a fine solution,
  # and if you have a local file, I recommend it. But you might want to peek at the class for a few additional
  # options/details (for example, you can use one of its methods to MAKE a CSV file from what you already have...)
  desc "Make the parents from a CSV file, provided as the fname argument (MV's method)"
  task :make_parents, [:fname] => :environment do |t, args|
    skip_count = 0
    done_count = 0

    CSV.foreach(
      args[:fname],
      :headers => true,
      :header_converters => :symbol
    ) do |row|
      puts "-------------------------------"
      puts "Child: #{row[:child]}"
      puts "Parent: #{row[:parent]}"

      cterm = TraitBank.term(row[:child])
      pterm = TraitBank.term(row[:parent])

      if (cterm && pterm)
        TraitBank.child_term_has_parent_term(cterm, pterm)
        done_count += 1
        puts "Created"
      else
        skip_count += 1
        puts "Skipped"
      end
    end

    puts "#{done_count} relationships created"
    puts "#{skip_count} relationships skipped"
  end
end
