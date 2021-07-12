count = 0

Resource.find_each do |r|
  node = ResourceNode.find_by(resource_id: r.id)

  if node
    count += 1

    node.update!(
      name: r.name,
      description: r.description,
      repository_id: r.repository_id
    )
  end
end

puts "#{count} (of #{Resource.count}) ResourceNodes found and updated"

