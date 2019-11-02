begin
  Page::Descendants.load
rescue => e
  puts "Failed to load descendant counts!"
  puts e
end
