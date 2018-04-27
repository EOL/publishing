cd TraitBank

no_results = query(%{MATCH (page:Page)-[:parent*0..]->(:Page { page_id: 1 }),
(page)-[:trait]->(t0:Trait)-[:predicate]->(:Term)-[:parent_term|:synonym_of*0..]->(p0:Term),
(t0:Trait)-[:object_term]->(:Term)-[:parent_term|:synonym_of*0..]->(o0:Term)
WHERE (o0.uri = "http://www.wikidata.org/entity/Q16"
AND p0.uri = "http://eol.org/schema/terms/Present")
RETURN DISTINCT(page)
LIMIT 5})["data"].map { |r| r.first && r.first["data"] }

other_canada = query(%{MATCH (page:Page)-[:parent*0..]->(:Page { page_id: 1 }),
(page)-[:trait]->(t0:Trait)-[:predicate]->(:Term)-[:parent_term|:synonym_of*0..]->(p0:Term),
(t0:Trait)-[:object_term]->(:Term)-[:parent_term|:synonym_of*0..]->(o0:Term)
WHERE (o0.uri = "http://www.geonames.org/6251999"
AND p0.uri = "http://eol.org/schema/terms/Present")
RETURN DISTINCT(page)
LIMIT 5})["data"].map { |r| r.first && r.first["data"] }

only_canada = query(%{MATCH (page:Page)-[:parent*0..]->(:Page { page_id: 1 }),
(page)-[:trait]->(t0:Trait)-[:object_term]->(:Term)-[:parent_term|:synonym_of*0..]->(o0:Term)
WHERE (o0.uri = "http://www.wikidata.org/entity/Q16")
RETURN DISTINCT(page)
LIMIT 5})["data"].map { |r| r.first && r.first["data"] }

only_canada_no_clade = query(%{MATCH
(page)-[:trait]->(t0:Trait)-[:object_term]->(:Term)-[:parent_term|:synonym_of*0..]->(o0:Term)
WHERE (o0.uri = "http://www.wikidata.org/entity/Q16")
RETURN DISTINCT(page)
LIMIT 50})["data"].map { |r| r.first && r.first["data"]["page_id"] }

--

no_results = query(%{MATCH (page:Page)-[:parent*0..]->(Page { page_id: 1642 }), (page)-[:trait]->(t0:Trait)-[:predicate]->(predicate:Term)-[:parent_term|:synonym_of*0..]->(p0:Term), (page)-[:trait]->(t1:Trait)-[:predicate]->(predicate:Term)-[:parent_term|:synonym_of*0..]->(p1:Term)
WHERE p0.uri = "http://eol.org/schema/terms/Present"
AND p1.uri = "http://eol.org/schema/terms/Habitat"
RETURN page
LIMIT 50})["data"]

one_clause = query(%{MATCH (page:Page)-[:parent*0..]->(Page { page_id: 1642 }),  (page)-[:trait]->(t1:Trait)-[:predicate]->(predicate:Term)-[:parent_term|:synonym_of*0..]->(p1:Term)
WHERE p1.uri = "http://eol.org/schema/terms/Habitat"
RETURN page
LIMIT 2})["data"].map { |r| r ? r.first["data"]["page_id"] : nil }

other_clause = query(%{MATCH (page:Page)-[:parent*0..]->(Page { page_id: 1642 }),  (page)-[:trait]->(t1:Trait)-[:predicate]->(predicate:Term)-[:parent_term|:synonym_of*0..]->(p1:Term)
WHERE p1.uri = "http://eol.org/schema/terms/Present"
RETURN page
LIMIT 2})["data"].map { |r| r ? r.first["data"]["page_id"] : nil }

totally_will_work = query(%{MATCH (page:Page)-[:parent*0..]->(Page { page_id: 1642 }), (page)-[:trait]->(t0:Trait)-[:predicate]->(predicate0:Term)-[:parent_term|:synonym_of*0..]->(p0:Term), (page)-[:trait]->(t1:Trait)-[:predicate]->(predicate1:Term)-[:parent_term|:synonym_of*0..]->(p1:Term)
WHERE p0.uri = "http://eol.org/schema/terms/Present"
AND p1.uri = "http://eol.org/schema/terms/Habitat"
RETURN page
LIMIT 50})["data"].map { |r| r ? r.first["data"]["page_id"] : nil }


--

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
