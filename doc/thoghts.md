# TraitBank

## What do we want TraitBank to be?

* Informing an encyclopedia?
* Answering scientific questions?
* Focused on individual occurrence data, or curated range data?
* Alerting for observations (e.g.: on iNat) outside of expectations?

How will TB scale? Do we eventually shard on clades in order to store specific information? (e.e.: specific insect measurements)

## Things to keep in mind

* You want to be able to query for all data "types" at once (numerical, categorical, relationship and literal).
* It will be important to store aggregate data at higher-level nodes
  * JR thinks that aggregate data may not be well-suited to a triple-store ... it fits in an RDBMS DB quite nicely, even for categorical data (numerical data should be stored in blocks).
*

## CAUTION!

Don't build TB with queries in mind that are ultimately unmaintainable. (keep in mind: we *could* only allow certain filters to apply after larger filters have been applied: like lifestage after clade selection)
