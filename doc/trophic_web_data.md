# Trophic Web Data

This document describes the JSON data that is used by the trophic web visualizations found on the data tab. 

## Url
Data for a source page with id `page_id` is found at `/api/pages/<page_id>/pred_prey.json`. eg: https://eol.org/api/pages/620727/pred_prey.json

## JSON
```json
{
  "nodes": [...],
  "links": [...]
}
```

`nodes` are classified into four groups: `"source"`, `"predator"`, `"prey"`, `"competitor"`. `"source"` is the source taxon in the predator and prey records. It is the focal species, the point of reference for the rest of the trophic web, and a `"competitor"` is a predator of a `"prey"` node. There is a limit of 10 nodes per group (and there will only be one `"source"` node). In order for a node to be included, it must have a rank of species or lower (subspecies, etc.), as well as have an icon.

`node` attributes:
  * `id`: the `page_id` for the taxon 
  * `group`: one of the group values described above
  * `groupDesc`: a more verbose description of how this node relates to the source node.
  * `icon`: taxon page icon url
  * `label`: The common name for the taxon if available, otherwise the scientific name
  * `labelWithItalics`: Same as `label`, but with `<i></i>` tags surrounding the portions that should be italicized.
  * `x`: convenience for visualization code, always 0.
  * `y`: same as `x`

`link` attributes:
  * `source`: the node `id` of the taxon that eats the `target`
  * `target`: the node `id` of the taxon that is eaten by the `source`

