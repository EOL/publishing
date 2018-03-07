require 'csv'

namespace :terms do
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
