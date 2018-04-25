cd TraitBank

modified = query %q{MATCH (page:Page)-[:parent*]->(:Page { page_id: 1642 }),
(page)-[:trait]->(trait:Trait),
(trait)-[:predicate]->(predicate:Term),
(predicate)-[:parent_term|:synonym_of*]->(tgt_pred:Term),
(trait)-[:supplier]->(resource:Resource)
WHERE tgt_pred.uri = "http://eol.org/schema/terms/Present"
OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
OPTIONAL MATCH (trait)-[:normal_units_term]->(normal_units:Term)
OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
RETURN page, trait, predicate, units, normal_units, object_term, sex_term, lifestage_term, statistical_method_term, resource
LIMIT 1}

works_sep = query %{MATCH (page:Page)-[:parent*]->(:Page { page_id: 1642 }),
(page)-[:trait]->(trait:Trait),
(trait)-[:predicate]->(predicate:Term),
(predicate)-[:parent_term|:synonym_of*0..]->(tgt_pred:Term),
(trait)-[:supplier]->(resource:Resource)
WHERE tgt_pred.uri = "http://eol.org/schema/terms/Present"
OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
OPTIONAL MATCH (trait)-[:normal_units_term]->(normal_units:Term)
OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
RETURN page, trait, predicate, resource
LIMIT 1}
