namespace :comments do
  desc 'Sets the canonical_form propertiess on all pages in neo4j.'
  task rm_empty: :environment do
    puts "Starting..."
    Comments.delete_empty_comment_topics
    puts "Done."
  end
end
