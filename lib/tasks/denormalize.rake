namespace :denormalize do
  desc 'Sets the canonical_form propertiess on all pages in neo4j.'
  task traits: :environment do
    puts "Starting..."
    TraitBank::Denormalizer.set_canonicals
    puts "Done."
  end
end
