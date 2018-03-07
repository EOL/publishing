
# Trait 'Schema'

This document expands on a comment in file
[trait_bank.rb](../app/models/trait_bank.rb) and incorporates
information provided by Jeremy.  Any errors (as of initial checkin)
are my own (JAR), and I am not an expert so there may be many of them.

## About neo4j - in case you don't know all this already

Neo4j doesn't have a notion of schema, exactly, but in the general
sense of how the information at hand relates to what is in the graph
database, the following describes the schema for traits and
neighboring entities.

Neo4j has 'nodes', and nodes can have typed properties, with values
that are scalars such as strings and numbers, and typed links
(sometimes called relationships, or arcs) to other nodes.  Links have
a 'source' or 'origin', and a 'target' or 'destination'.  Below we
show link types in the section for each origin node type, but neo4j
has no particular source vs. target bias.

Properties and relationships can both be many to many.  Property
values are unique unless otherwise specified.

## Resource

A `Resource` node corresponds to a 'resource' defined here as a file
or set of files, imported from outside of the EOL project (usually?
always? from the Web), that provides specific scalar information about
taxa, such as average adult mass.  This information is recorded in the
properties of `Trait` nodes, and of nodes that `Trait` nodes link to
or from.

* `resource_id` property - Every `Resource` node has a different
  `resource_id` property value.  
  This value can be used as a key 
  in tables stored in one or more RDBMSes, where further information about the 

## Page

A `Page` node is meant to correspond to a taxon (or 'taxon concept').
A taxon contains organisms or specimens.  Of course the correspondence
will fail once in a while due to errors in the input data, in taxon
record matching (the harvester), or in what we believe about nature.
These situations are errors and should be fixed when detected.

* `parent` link (to another `Page` node): taxonomic
  subsumption; the target is intended to be the Page for the smallest
  taxon that has a `Page` and contains, but is different from, the one
  for this Page.  Unique, and always present except for the root
  `Page`.  The name is a reference to the user interface where each
  taxon known to EOL has its own web page.
* `trait` relationship (to a `Trait` node): the target node gives information
  (mostly but not always quantitative)
  about the taxon.  Many `Trait`s (or no
  `Trait`s) can be `trait`-related a given `Page`.
* `page_id` property, a positive integer.
  Every `Page` has a different `page_id`.  This is used as a key in 
  many of the EOL relational databases, which contain taxon
  information beyond, or redundant with, what the neo4j graph db holds.
  Always present.

Additional information about the taxon, such as the name or scientific
name that EOL gives it, can be obtained from the web site RDB (or ORM)
using the `page_id` as a key.


## Trait

A `Trait` node corresponds to some kind of claim about a taxon (or
rather its members).  As usual a claim can be true or false, but these `Trait`
claims are intended to be true.  Of course they will not
always be so.

The central claim of a `Trait` node, like most claims, has a subject,
a verb (or predicate), and an object.  The subject is the taxon that
the `Page` node is about (i.e. the taxon for the `Page` node that
links to this `Trait` node via a `trait` link) is about.  The verb is
given by the `predicate` link, and the object is given by one of the
`Trait` node properties or links, as described below.

(what to say about 'associations'?)

### General information about the claim

* `eol_pk` property: an uninterpreted value that is different
  for every `Trait` node.  Always present.
* `resource_pk` property: a key for the claim within the resource; 
  that is, each claim from a given resource has a different `resource_pk`
  value.  Always present.  
* `source` property: Value copied from a DwCA. Meant to describe the original source
  of the `Trait` information (since the resource is itself an aggregator).  
  Free text. Often quite long. Semantics unclear.
* `metadata` link: information (claims!) about this claim; see below.
  The node may be `metadata`-linked to any number of other nodes.

### Subject and predicate

The subject is given as the (unique) `Page` node that `trait`-links to
this `Trait` node.

* `scientific_name` property: the name that the resource provided for the 
  subject taxon; not necessarily the same as EOL's name for the taxon (which is the name
  associated in the RDB with the `page_id` for the subject's `Page`).
* `predicate` link: links to a `Term` node, usually one for an ontology
  term; see below for `Term`.  Always present.

### Object (or value) of the claim

Exactly one of `object_page_id`, `object_term`, `normal_measurement`, or
`literal` will be present, and specifies the 'object' or value of the
claim.

* `object_page_id`: if the object of the claim is a taxon, this is the 
  value of the `page_id` property of the `Page` node for the taxon.
* `object_term` link: to a `Term` node for the object of the claim,
  usually an ontology term for some qualititative choice (e.g. habitat type).
* `normal_measurement` property: if the `predicate` indicates a quantitive
   property of the subject taxon, then this property gives that quantity.
* `measurement` property: like `normal_measurement` but as the value is written 
  in the resource; might use different units
* `normal_units_term` link: when `normal_measurement` is present, the target is a `Term` node (usually 
  for an ontology term) describing the units of `normal_measurement`.  (??)
* `units_term` link: when `measurement` is present, the target is a `Term` node (usually 
  for an ontology term) describing the units of `measurement`.  (?? to be removed)
* `normal_units` property: textual description of the units
* `literal` property: a string coming from an uncontrolled vocab such as 
  certain Darwin Core fields.

### Qualifiers

The claim may not be uniformly true of everything in the taxon, but
rather applies only to some subset.

The following properties hold text for the web site to use; the text
is derived from ontology terms that are not stored.

* `statistical_method` property
* `sex` property
* `lifestage` property

### Metadata

A `Metadata` node expresses something we have know or believe either
about the `Trait` node's main claim, the way the information was
gathered, or the way in which it is expressed in the `Trait` node.

Some `Metadata` nodes are a more rigorous expression of information in
the `Trait` node, providing an ontology term rather than free text.

* `eol_pk`     always present - unique to this `Metadata` node
* `predicate` link (to a `Term`)      Example: target could be a term 
      indicating that the measurement value gives the sample size.  Always present
* `object_term` link (to a `Term`)
* `units_term` link (to a `Term`)
* `measurement`      e.g. the sample size
* `literal`

### Term

`Term` nodes correspond (usually?) to ontology terms, elements of some
origin document such as an ontology or controlled vocabulary.  Terms
are written as URLs (URIs) and the origin provides them with a name,
description, and other information such as type and subsumption
relationships.

Terms live in neo4j (copied from harvesting db) and *not* in the web
site RDB.

* `uri` property -    always present
* `name` property -   an English word or phrase, chosen by EOL curators, but usually the canonical 
  name as provided by the origin ontology.  always present
* `type` property -      predicate, object, unit, ?metadata? - for type checking.
  Possible values as of this writing are "measurement", "association", "value",
  and "metadata".
* `definition` property -   from ontology
* `comment` property -      EOL curator note
* `attribution` property -  might say that term's source is OBO
* `section_ids` property, string with comma separated fields.  hairy. see RDMS.
     the sections of the TOC in which the term occurs.  always present
* `is_hidden_from_overview` property - hidden from the trait overview on a web page
* `is_hidden_from_glossary` property 
* `position` property -  an integer assigned only to this term, related to summary ordering on web page
