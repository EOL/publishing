# Example queries


The traits database is stored as a neo4j 'graph'.  The schema (node
types and properties) is described in the [trait schema
document](https://github.com/EOL/eol_website/blob/master/doc/trait-schema.md). New
Cypher users may find neo4j's [Cypher
documentation](https://neo4j.com/docs/developer-manual/current/cypher/)
helpful.  [This
document](https://www.remwebdevelopment.com/blog/sql/some-basic-and-useful-cypher-queries-for-neo4j-201.html)
on basic Cypher use is also handy.

For general information on using the API, see [api.md](api.md) and
[api-access.md](api-access.md).


## Show ancestry (lineage)

Find the lineage of a given taxon (page) using the Cypher transitive
closure feature (`*`):

```
MATCH (origin:Page {page_id: 1267598})-[:parent*]->(ancestor:Page)
OPTIONAL MATCH (ancestor)-[:parent]->(parent_of_ancestor:Page)
RETURN ancestor.page_id, ancestor.canonical, parent_of_ancestor.page_id
LIMIT 100
```

Result:

```
{
  "columns": [
    "ancestor.page_id", 
    "ancestor.canonical", 
    "parent_of_ancestor.page_id"
  ], 
  "data": [
    [
      328598, 
      "Procyon lotor", 
      18666
    ], 
    [
      18666, 
      "Procyon", 
      7665
    ], 
...
```

The above query shows only the lineage starting at the _parent_ of the
given taxon.  To include a single additional record for the given
taxon showing its parent id of the given taxon, use `UNION ALL`: (this
query also illustrates column renaming)

```
MATCH (origin:Page {page_id: 1267598})-[:parent]->(parent:Page)
RETURN origin.page_id AS page_id,
       origin.canonical AS canonical,
       parent.page_id AS parent_id
UNION ALL MATCH (origin:Page {page_id: 1267598})-[:parent*]->(ancestor:Page)
OPTIONAL MATCH (ancestor)-[:parent]->(parent:Page)
RETURN ancestor.page_id AS page_id, 
       ancestor.canonical AS canonical,
       parent.page_id AS parent_id
LIMIT 100
```

Result:
```
{
  "columns": [
    "page_id", 
    "canonical", 
    "parent_id"
  ], 
  "data": [
    [
      1267598, 
      "Procyon lotor pallidus", 
      328598
    ], 
    [
      328598, 
      "Procyon lotor", 
      18666
    ], 
...
```

## Number of descendant taxa

The following query counts the number of descendant taxa of a given
taxon, in this case mammals (page id 1642).  (This number is usually
close to the number of species, but subspecies and intermediate taxa
are also included in the count.)

```
MATCH (descendant:Page)-[:parent*]->(ancestor:Page {page_id: 1642})
RETURN COUNT(descendant)
LIMIT 1
```

## Show a sample of trait records

The following Cypher query shows basic information recorded in an
arbitrarily chosen set of Trait nodes.

```
MATCH (t:Trait)<-[:trait]-(p:Page),
      (t)-[:supplier]->(r:Resource),
      (t)-[:predicate]->(pred:Term)
OPTIONAL MATCH (t)-[:object_term]->(obj:Term)
OPTIONAL MATCH (t)-[:normal_units_term]->(units:Term)
OPTIONAL MATCH (lit:Term) WHERE lit.uri = t.literal
RETURN r.resource_id, t.eol_pk, t.resource_ok, t.source, p.page_id, t.scientific_name, pred.uri, pred.name,
       t.object_page_id, obj.uri, obj.name, t.normal_measurement, units.uri, units.name, t.normal_units, t.literal, lit.name
LIMIT 5
```
## Show (numerical) value of a predicate, for a given taxon

This query shows a value and limited metadata for a specific predicate and taxon. This construction presumes you know that this predicate has numerical values. It can be called using identifiers for the taxon (the EOL identifier, corresponding to the number in the taxon page URL, eg: https://eol.org/pages/328651) and trait predicate (the term URI for the predicate)

```
MATCH (t:Trait)<-[:trait]-(p:Page),
(t)-[:supplier]->(r:Resource),
(t)-[:predicate]->(pred:Term)
WHERE p.page_id = 328651 AND pred.uri = "http://purl.obolibrary.org/obo/VT_0001259"
OPTIONAL MATCH (t)-[:units_term]->(units:Term)
RETURN p.canonical, pred.name, t.measurement, units.name, r.resource_id, p.page_id, t.eol_pk, t.source
LIMIT 1
```
or using strings for the taxon name and trait predicate name (with attendant risk of homonym confusion)

```
MATCH (t:Trait)<-[:trait]-(p:Page),
(t)-[:supplier]->(r:Resource),
(t)-[:predicate]->(pred:Term)
WHERE p.canonical = "Odocoileus hemionus" AND pred.name = "body mass"
OPTIONAL MATCH (t)-[:units_term]->(units:Term)
RETURN p.canonical, pred.name, t.measurement, units.name, r.resource_id, p.page_id, t.eol_pk, t.source
LIMIT 1
```
This is a query type which may benefit from a metadata filter, eg: for lifestage, and from a check for child terms representing subclasses of the term of interest

```
MATCH (t:Trait)<-[:trait]-(p:Page),
(t)-[:predicate]->(pred:Term)-[:parent_term|:synonym_of*0..]->(parent:Term),
(t)-[lifestage_term]->(stage:Term)
WHERE p.canonical = "Odocoileus hemionus" AND parent.name = "body mass" AND stage.name = "adult"
OPTIONAL MATCH (t)-[:units_term]->(units:Term)
RETURN p.canonical, pred.name, t.measurement, units.name, t.source
LIMIT 1
```

## Show (categorical) value of a predicate, for a given taxon

This query shows a value and limited metadata for a specific predicate and taxon. This construction presumes you know that this predicate has categorical values known to EOL by structured terms with URIs. Here is the construction using strings for the taxon name and trait predicate name (with attendant risk of homonym confusion)

```
MATCH (t:Trait)<-[:trait|:inferred_trait]-(p:Page),
(t)-[:supplier]->(r:Resource),
(t)-[:predicate]->(pred:Term)
WHERE p.canonical = "Odocoileus hemionus" AND pred.name = "ecomorphological guild"
OPTIONAL MATCH (t)-[:object_term]->(obj:Term)
RETURN p.canonical, pred.name, obj.name, r.resource_id, p.page_id, t.eol_pk, t.source
LIMIT 1
```
## Show (taxa) values of a predicate, for a given taxon

This query shows the EOL taxa for five ecological partners associated by a specific predicate to a taxon, with limited metadata. This construction presumes you know that this predicate is for ecological interactions with other taxa. Here is the construction using strings for the taxon name and predicate name, and returning strings for the ecological partner taxon name (with attendant risk of homonym confusion)

```
MATCH (p:Page)-[:trait|:inferred_trait]->(t:Trait),
(t)-[:supplier]->(r:Resource),
(t)-[:predicate]->(pred:Term)
WHERE p.canonical = "Enhydra lutris" AND pred.name = "eats"
MATCH (p2:Page {page_id:t.object_page_id}) 
RETURN  p.canonical, pred.name, p2.canonical, r.resource_id, p.page_id, t.eol_pk, t.source
LIMIT 5
```

## Show values of several record types, wherever all are available for a given taxon

This query shows a value for each of three record types, for any taxon that has all three. Two record types are for the same predicate (body mass) at different lifestages (newborn and adult). The third is for a different predicate (litter size). This construction presumes that body mass records must have units. You could include additional metadata, either as constraints on the match, or as values to return.

```
MATCH (t:Trait)<-[:trait|:inferred_trait]-(p:Page),
(t)-[:predicate]->(pred:Term {uri: "http://purl.obolibrary.org/obo/VT_0001259"}),
(t)-[:units_term]->(units1:Term),
(t)-[:lifestage_term]->(stage1:Term {uri:"http://purl.bioontology.org/ontology/CSP/0070-1441"}),
(t1:Trait)<-[:trait|:inferred_trait]-(p:Page),
(t1)-[:predicate]->(pred:Term {uri: "http://purl.obolibrary.org/obo/VT_0001259"}),
(t1)-[:units_term]->(units2:Term),
(t1)-[:lifestage_term]->(stage2:Term {uri:"http://www.ebi.ac.uk/efo/EFO_0001272"}),
(t2:Trait)<-[:trait|:inferred_trait]-(p:Page),
(t2)-[:predicate]->(pred2:Term {uri: "http://purl.obolibrary.org/obo/VT_0001933"})
RETURN p.canonical, t.measurement, units1.name, stage1.name, t1.measurement, units2.name, stage2.name, pred2.name, t2.measurement
LIMIT 40
```

## Provenance of trait record

Provenance metadata can be found as properties on the trait node or as linked MetaData nodes. 

Properties: t.source, if available, is a URL provided by the data partner, pointing to the original data source. Other properties are identifiers which can be used to construct URLs. For instance, r.resource_id can be used to construct a resource url like https://eol.org/resources/396. The EOL trait record URL of the form https://eol.org/pages/328651/data#trait_id=R261-PK22175282 can be constructed from p.page_id and t.eol_pk.  

Nodes: Most other provenance information can be found on MetaData nodes with three predicates. Adding the following to your query will fetch one of each, if present:
```
OPTIONAL MATCH (t)-[:metadata]->(contr:MetaData)-[:predicate]->(:Term {name:"contributor"})
OPTIONAL MATCH (t)-[:metadata]->(cite:MetaData)-[:predicate]->(:Term {name:"citation"})
OPTIONAL MATCH (t)-[:metadata]->(ref:MetaData)-[:predicate]->(:Term {name:"Reference"})
RETURN contr.literal, cite.literal, ref.literal
```
Where references are present, there may be more than one; to ensure you have them all, you can run an additional query. Multiple contributors are also possible, but rare.

to fetch multiple references for a given trait record:

```
MATCH (t)-[:metadata]->(ref:MetaData)-[:predicate]->(:Term {name:"Reference"})
WHERE t.eol_pk = "R483-PK24828656"
RETURN ref.literal
LIMIT 5
```

## Show all categorical value terms available for this predicate 

This query shows all categorical values represented in records for a given predicate and its children. For instance, woodiness is a child of growth habit, so categorical values for records with a predicate of woodiness will also be found by this query.

```
MATCH (t0:Trait)-[:predicate]->(p0:Term)-[:parent_term|:synonym_of*0..]->(tp0:Term),
(t0)-[:object_term]->(obj:Term)
WHERE tp0.uri = "http://eol.org/schema/terms/growthHabit"
RETURN DISTINCT obj.name, obj.uri
LIMIT 50;
```

## Show all predicate terms 

These queries show all terms labeled for use as predicates in EOL. This is a shorthand, because querying for all terms *used* as predicates in the graph is too slow. Note that predicates for ecological association records have a different label

```
MATCH (t:Term {type:"measurement"})
RETURN DISTINCT t.name, t.uri
LIMIT 900;
```

```
MATCH (t:Term {type:"association"})
RETURN DISTINCT t.name, t.uri
LIMIT 100;

```


## Show all predicate terms for size 

These queries show all terms used as predicates and classified as children of Size (PATO_0000117). Children are considered subclasses of the parent term, and may be preferred or deprecated as synonyms. 

```
MATCH (t:Trait)-[:predicate]->(p:Term)-[:parent_term|:synonym_of*0..]->(pred:Term)
WHERE pred.uri="http://purl.obolibrary.org/obo/PATO_0000117"
RETURN DISTINCT p.name, p.uri
LIMIT 100;
```

## For how many taxa does EOL have a measure of size?

This query shows the number of taxa in EOL that have trait records with a predicate that is size (http://purl.obolibrary.org/obo/PATO_0000117) or a subclass of size like wingspan, body mass, etc.

```
MATCH (taxa:Page)-[:trait|:inferred_trait]->(t:Trait)-[:predicate]->(p:Term)-[:parent_term|:synonym_of*0..]->(pred:Term)
WHERE pred.uri="http://purl.obolibrary.org/obo/PATO_0000117"
RETURN COUNT(DISTINCT taxa)
LIMIT 1;
```

## How many data providers contribute size records to EOL?

This query shows the number of contributing data providers which include records of body mass, cell volume, wingspan, or other measures of size, in their data published to EOL. Note that a given provider may have aggregated their own data, so the records from a given provider may have different citations or references.

```
MATCH (t:Trait)-[:supplier]->(r:Resource),
(t:Trait)-[:predicate]->(p:Term)-[:parent_term|:synonym_of*0..]->(pred:Term)
WHERE pred.uri="http://purl.obolibrary.org/obo/PATO_0000117"
RETURN COUNT (DISTINCT r)
LIMIT 1;
```

## How many records do the most common trait predicates have?

```
MATCH (:Trait)-[:predicate]->(t:Term)
WITH t, count(*) AS count
RETURN t.name, t.uri, count
ORDER BY count desc
LIMIT 10
```

## How many records do the most common habitat values have?

(This query happens to be informative for habitat because nearly all of our habitat terms are provided by the ENVO ontology.)

```
MATCH (:Trait)-[:object_term]->(t:Term)
WHERE t.uri =~ ".*\\/ENVO.*"
WITH t, count(*) AS count
RETURN t.name, t.uri, count
ORDER BY count desc
LIMIT 15
```

## Which taxa visit flowers of taxa that have records of human use?

```
MATCH (page:Page), (page)-[:trait|:inferred_trait]->(t0:Trait), 
(t0)-[:predicate]->(:Term)-[:parent_term|:synonym_of*0..]->(p0:Term), 
(page)-[:trait|:inferred_trait]->(t1:Trait), 
(t1)-[:predicate]->(:Term)-[:parent_term|:synonym_of*0..]->(p1:Term), 
(page2:Page)
USING INDEX p0:Term(uri)
USING INDEX p1:Term(uri)
WHERE (p0.uri = "http://eol.org/schema/terms/Uses")
AND (p1.uri = "http://purl.obolibrary.org/obo/RO_0002623")
AND (t1.object_page_id = page2.page_id)
RETURN DISTINCT page.canonical, page2.canonical
LIMIT 50000
```

## Taxa marked both extant and extinct

```
WITH 'http://eol.org/schema/terms/ExtinctionStatus' AS uri
MATCH (p:Page)-[:trait|:inferred_trait]->(t:Trait)-[:predicate]->
      (:Term {uri: uri}),
      (t)-[:object_term]->(o:Term)
WITH p, COLLECT(DISTINCT o.uri) AS values
WHERE SIZE(values) > 1
RETURN p.page_id, p.canonical
LIMIT 100
```

## Extinct taxa with extant descendants

```
WITH 'http://eol.org/schema/terms/ExtinctionStatus' AS status
MATCH (d:Page)-[:parent*0..]->(a:Page),
      (a)-[:trait|:inferred_trait]->(at:Trait)-[:predicate]->(:Term {uri: status}),
      (at)-[:object_term]->(:Term {uri: 'http://eol.org/schema/terms/extinct'}),
      (d)-[:trait|:inferred_trait]->(dt:Trait)-[:predicate]->(:Term {uri: status}),
      (dt)-[:object_term]->(:Term {uri: 'http://eol.org/schema/terms/extant'})
RETURN a.page_id, a.canonical, d.page_id, d.canonical
LIMIT 100
```
