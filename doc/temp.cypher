query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(trait)-[:predicate]->(predicate:Term),
(page)-[:parent*]->(Page { page_id: 18666 })
WHERE (trait)-[:predicate|parent_term*0..4]->(:Term{ uri: "http://eol.org/schema/terms/AgeAtEyeOpening" })
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
ORDER BY LOWER(predicate.name), LOWER(info_term.name), trait.normal_measurement, LOWER(trait.literal)
LIMIT 50
}
res = TraitBank.query(query)["data"].size
# That takes about 13s, no results.

# NO parent terms, takes about 6sec, no results.
query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(trait)-[:predicate]->(predicate:Term),
(page)-[:parent*]->(Page { page_id: 18666 })
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
ORDER BY LOWER(predicate.name), LOWER(info_term.name), trait.normal_measurement, LOWER(trait.literal)
LIMIT 50
}
res = TraitBank.query(query)["data"].size

# NO parent terms OR clade filter, takes about 7.5sec, 50 results
query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(trait)-[:predicate]->(predicate:Term)
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
ORDER BY LOWER(predicate.name), LOWER(info_term.name), trait.normal_measurement, LOWER(trait.literal)
LIMIT 50
}
res = TraitBank.query(query)["data"].size

# move clade filter to WHERE, took 23.5 sec, no results!
query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource)
WHERE (page)-[:parent*]->(:Page { page_id: 18666 })
MATCH (trait)-[:predicate]->(predicate:Term)
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
ORDER BY LOWER(predicate.name), LOWER(info_term.name), trait.normal_measurement, LOWER(trait.literal)
LIMIT 50
}
res = TraitBank.query(query)["data"].size

# NO parent terms OR clade filter, NO ORDER BY takes about 0.5sec, 50 results!!!!
query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(trait)-[:predicate]->(predicate:Term)
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
LIMIT 50
}
res = TraitBank.query(query)["data"].size

# NO parent terms OR clade filter, NO ORDER BY  ... adding page WHERE as named node: nothing, slow
query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(trait)-[:predicate]->(predicate:Term), (ancestor:Page { page_id: 18666 })
WHERE (page)-[:parent*]->(ancestor)
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
LIMIT 50
}
res = TraitBank.query(query)["data"].size

# Okay, nothing is in this clade (Procyon) in TB. :S
res = TraitBank.query("MATCH (page:Page)-[:parent]->(ancestor:Page { page_id: 18666 }) RETURN COUNT(page)")["data"]

# Let's find A page (raccoon) and it's parents:
res = TraitBank.query("MATCH (page:Page { page_id: 328598 })-[:parent]->(parent:Page) RETURN parent")["data"]
