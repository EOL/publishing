class TraitBank
  def DataDownload
    columns = {
      "EOL Page ID" => "page.id", # NOTE: might be nice to make this clickable?
      "Ancestry" => %Q{page.native_node.ancestors.map { |n| n.canonical_form }.join(" | ")},
      "Scientific Name" => %Q{page.scientific_name},
      "Common Name" => %Q{page.vernacular.try(:string)},
      "Measurement" => %Q{trait.predicate.name},
      "Value" => %Q{trait.value}, # NOTE this is actually more complicated...
      "Measurement URI" => %Q{trait.predicate.uri},
      "Value URI" => %Q{trait.object_term.try(:uri)},
      "Units (normalized)" => %Q{}, # YOU WERE HERE
      "Units URI (normalized)" => %Q{},
      "Raw Value (direct from source)" => %Q{},
      "Raw Units (direct from source)" => %Q{},
      "Raw Units URI (normalized)" => %Q{},
      "measurement method" => %Q{},
      "statistical method" => %Q{},
      "individual count" => %Q{},
      "locality" => %Q{},
      "event date" => %Q{},
      "measurement remarks" => %Q{},
      "life stage" => %Q{},
      "measurement determined date" => %Q{},
      "sex" => %Q{},
      "occurrence remarks" => %Q{},
      "Supplier" => %Q{},
      "Content Partner Resource URL" => %Q{},
      "source" => %Q{},
      "citation" => %Q{},
      "References" => %Q{}
    }
  end
end
