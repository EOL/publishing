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
// That takes about 13s, no results.

// NO parent terms, takes about 6sec, no results.
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

// NO parent terms OR clade filter, takes about 7.5sec, 50 results
query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(trait)-[:predicate]->(predicate:Term)
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
ORDER BY LOWER(predicate.name), LOWER(info_term.name), trait.normal_measurement, LOWER(trait.literal)
LIMIT 50
}
res = TraitBank.query(query)["data"].size

// NO ORDER: Take no firggin time at all, 50 res.
query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(trait)-[:predicate]->(predicate:Term)
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
LIMIT 50
}
res = TraitBank.query(query)["data"].size

// FULL, no order: TAKES LONGER (16s)
// FULL, no clade, with ORDER: same time (12s)
// FULL, no parent term, with ORDER: INSTANT.

MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(tgt_pred_1:Term{ uri: "http://purl.obolibrary.org/obo/VT_0001259" }),
(trait)-[:predicate]->(predicate:Term),
(trait)-[:predicate|parent_term*0..4]->(tgt_pred_1)
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
ORDER BY LOWER(predicate.name), LOWER(info_term.name), trait.normal_measurement, LOWER(trait.literal)
LIMIT 50

query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(target_term:Term{ uri: "http://eol.org/schema/terms/AgeAtEyeOpening" }),
(trait)-[:predicate]->(predicate:Term)-[:predicate|parent_term*0..4]->(target_term),
(page)-[:parent*]->(Page { page_id: 18666 })
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
ORDER BY LOWER(predicate.name), LOWER(info_term.name), trait.normal_measurement, LOWER(trait.literal)
LIMIT 50
}
res = TraitBank.query(query)["data"].size

query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(tgt_pred_1:Term{ uri: "http://rs.tdwg.org/dwc/terms/habitat" }),
(tgt_obj_1:Term{ uri: "http://purl.obolibrary.org/obo/ENVO_00002037" }), (tgt_pred_1)<-[parent_term*0..4]-(predicate:Term)<-[:predicate]-(trait)-[:object_term]->(object_term:Term)-[parent_term*0..4]->(tgt_obj_1)
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate,
TYPE(info)
AS info_type, info_term, resource
ORDER BY LOWER(predicate.name),
LOWER(info_term.name), trait.normal_measurement,
LOWER(trait.literal)
LIMIT 50
}
res = TraitBank.query(query)["data"].size

// MOVE TO WHERE - Works, but takes 6 seconds:
query = %q{
MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource),
(tgt_pred_1:Term{ uri: "http://purl.obolibrary.org/obo/VT_0001259" }),
(tgt_pred_2:Term{ uri: "http://purl.obolibrary.org/obo/VT_0001933" }),
(trait)-[:predicate]->(predicate:Term)
WHERE (predicate)-[:parent_term*0..4]->(tgt_pred_1)
  OR (predicate)-[:parent_term*0..4]->(tgt_pred_2)
OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource
ORDER BY LOWER(predicate.name), LOWER(info_term.name), trait.normal_measurement, LOWER(trait.literal)
LIMIT 50
}
res = TraitBank.query(query)["data"].size

// UNION  (WIP)
query = %q{
  MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource)
  (tgt_pred:Term{ uri: "http://purl.obolibrary.org/obo/VT_0001256" })
  (trait)-[:predicate]->(predicate:Term)-[:parent_term*0..4]->(tgt_pred)
  OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)
  RETURN page, trait, predicate,
  TYPE(info)
  AS info_type, info_term, resource
  ORDER BY LOWER(predicate.name),
  LOWER(info_term.name), trait.normal_measurement,
  LOWER(trait.literal)
  LIMIT 50
}
res = TraitBank.query(query)["data"].size
