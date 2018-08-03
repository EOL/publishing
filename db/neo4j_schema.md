# The Neo4j Schema
Please keep this schema summary comment in sync with the main schema documentation file found in the doc/ directory, and
reflect and schema changes in the main documentation file.

### NOTE:
in its current state, this is NOT done! Neography (a rails gem) uses a plain hash to store objects, and ultimately
we're going to want our own models to represent things. But in these early testing stages, this is adequate. Since this
is not its final form, there are no specs yet. ...We need to feel out how we want this to work, first.

### NOTE:
Should associated pages (below, stored as object_page_id) actually have an association, since we have Pages?
...Yes, but only if that's something we're going to query... and I don't think we do! So all the info is really in the
MySQL DB and thus just the ID is enough.

## The Labels, and their expected relationships and properties:
"Relationships" are only listed if they are outgoing. Attributes which are *italicized* are "required". Classes of
relationships, if enforced, are preceded by a :Colon, and notes about either type are in [square braces].

### Resource:
* **Relationships**: none
* **Attributes**: *resource_id*

### Page:
* **Relationships**: ancestor:Page[NOTE: unused as of Nov2017], parent:Page, trait:Trait
* **Attributes**: *page_id*, canonical_form

### Trait:
* **Relationships**: *predicate*:Term, *supplier*:Resource, metadata:MetaData, object_term:Term, units_term:Term,
  normal_units_term:Term, sex_term:Term, lifestage_term:Term, statistical_method_term:Term,
* **Attributes**: *eol_pk*, *resource_pk*, *scientific_name*, source, measurement, object_page_id, literal,
  normal_measurement

### MetaData:
* **Relationships**: *predicate*:Term, object_term:Term, units_term:Term
* **Attributes**: *eol_pk*, measurement, literal

### Term:
* **Relationships**: parent_term:Term
* **Attributes**: *uri*, *name*, *section_ids*[comma-separated], definition, comment, attribution,
  is_hidden_from_overview, is_hidden_from_glossary, position, type }

### NOTE:
The "type" for Term is one of "measurement", "association", "value", or "metadata" ... at the time of this writing.
