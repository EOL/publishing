require 'csv'

namespace :terms do
  desc "Make parent/child relationships between terms, reading the data from opendata (JR's method)"
  task fetch: :environment do
    count = TraitBank::Terms::ParentChildRelationships.fetch
    puts "Loaded #{count} parent/child relationships."
  end

  # NOTE: (from JR) ...oops. I didn't know this existed when I wrote ParentChildRelationships. This is a fine solution,
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
