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
>>>>>>> b4592e5c... api doc tweaks

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
## Show (categorical) value of a predicate, for a given taxon

This query shows a value and limited metadata for a specific predicate and taxon. This construction presumes you know that this predicate has categorical values known to EOL by structured terms with URIs. Here is the construction using strings for the taxon name and trait predicate name (with attendant risk of homonym confusion)

```
MATCH (t:Trait)<-[:trait]-(p:Page),
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
MATCH (p:Page)-[:trait]->(t:Trait),
(t)-[:supplier]->(r:Resource),
(t)-[:predicate]->(pred:Term)
WHERE p.canonical = "Enhydra lutris" AND pred.name = "eats"
WITH p, pred, t, r
MATCH (p2:Page {page_id:t.object_page_id}) 
RETURN  p.canonical, pred.name, p2.canonical, r.resource_id, p.page_id, t.eol_pk, t.source
LIMIT 5
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
Where references are present, there may be more than one; to ensure you have them all would require an additional query. Multiple contributors are also possible, but rare.

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
MATCH (t0:Trait)-[:predicate]->(p0:Term)-[:parent_term|:synonym_of*0..]->(tp0:Term)
WHERE tp0.uri = "http://eol.org/schema/terms/growthHabit"
OPTIONAL MATCH (t0)-[:object_term]->(object_term:Term)
RETURN DISTINCT object_term.name, object_term.uri
LIMIT 50;
```
