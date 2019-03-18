NOT IN THE GRAPH:
- Users, v2 Users, OpenAuth, etc
- Activity
- collections (and collected pages and articles / media collected pages, etc, etc)
- Jobs
- Curation
- Home Page Feed
- CMS
- Publishing Logs
- Node Ancestors. ...I'm hoping that's what a Graph does "right"
- PageRedirects (I think this will be more efficient in the DB)
- SearchSuggestions. ...Again, I think this will be more efficient in MySQL.
- SeoMeta
- Term Queries.
- UserDownloads and its accoutrements

## NOTES

Things in *italics* are indexed, in theory...

Some nodes have a resource_node_pk which may seem superfluous, but we use that during publishing to build the link.

I skipped Links. We still haven't used them.

I skipped Stylesheets and Javascripts. They never panned out. :\

## THOUGHTS

I think we should start tracking "publishes" or the like, to make cleanup easier. Hmmmn. Think about it. Consider also
the resource links and created_at and updated_at props. I'm not sure we need all of these...

// NOTE: I renamed "source_page_url" to "in_context_url" as it's more descriptive. Also "unmodified_source_url" instead
// of just "unmodified_url"
Medium:Content { format, subclass, description, base_url, unmodified_source_url, in_context_url }

Article:Content { source_url, body }

Content { *guid*, resource_pk, name, created_at, updated_at, *repository_id* }
(Content)-[:license]->(License)
(Content)-[:language]->(Language)
(Content)-[:location]->(Location)
(Content)-[:bibliographic_citation]->(BibliographicCitation)
(Content)-[:owner]->(Owner)
(Content)-*[:resource]*->(Resource)
(Content)-[:page]->(Page)
(Content)-[:rights_statement]->(RightsStatement)
(Content)->[:usage_statement]->(UsageStatement)

Attribution { value, created_at, updated_at, url, resource_pk }
(Content)-*[:attribution]*->(Attribution)
(Attribution)-[:role]->(Role)
(Attribution)-*[:resource]*->(Resource) # Denormalized.

BibliographicCitation { resource_node_pk, body, created_at, updated_at, repository_id* }
(BibliographicCitation)-[:resource]->(Resource) # Denormalized.

Identifier { resource_node_pk, *identifier*, repository_id }
(Node)-[:identifier]->(Identifier)
(Identifier)-[:resource]->(Resource) # Denormalized.

ImageInfo { resource_node_pk, original_size, large_size, medium_size, small_size, crop_x, crop_y, crop_w, created_at, updated_at, repository_id* }
(Medium)-[:info]->(ImageInfo)
(ImageInfo)-[:resource]->(Resource) # Denormalized.

Language { code, group*, can_browse_site }
[see other Labels for links]

LicenseGroup { key }
(License)-[:group]->(LicenseGroup)

License { name, source_url, icon_url, can_be_chosen_by_partners, created_at, updated_at }
[see other Labels for links]

Location { location, longitude, latitude, altitude, spatial_location }

UsageStatement { statement }
(UsageStatement)->[:resource]->(Resource)

RightsStatement { statement }
(RightsStatement)->[:resource]->(Resource)

Node { scientific_name, canonical_form, *resource_pk*, source_url, is_hidden, is_in_unmapped_area, created_at, updated_at, has_breadcrumb, landmark, *repository_id* }
(Node)-*[:resource]*->(Resource)
(Node)-*[:page]*->(Page)
(Node)-[:rank]->(Rank)
(Node)-*[:parent]*->(Node)

OccurrenceMap { url }
(Page)-[:occurrence_map]->(OccurrenceMap)

## I'm thinking, here:

PageContent { position, is_incorrect, is_misidentified, is_hidden, is_duplicate, is_low_quality, created_at, updated_at }
(Page)-*[:page_content]*->(PageContent)-[:content]->(Content)
(PageContent)-*[:resource]*->(Resource)
(PageContent)-*[:source_page]*->(Page)
(PageContent)-[:trust]->(Trust)

Trust { name } // unreviewed, trusted, untrusted

PageIcon { added_by_user_id, created_at, updated_at }
(Page)-[:icon]->(PageIcon)
(PageIcon)-[:medium]->(Medium)

Page { media_count, articles_count, maps_count, vernaculars_count, scientific_names_count, referents_count,
  species_count, is_extinct, is_marine, has_checked_extinct, has_checked_marine, iucn_status, trophic_strategy,
  geographic_context, habitat, page_richness, created_at, updated_at }
(Page)-[:native_node]->(Node)
(Page)-[:page_referent]->(PageReferent)

PageReferent { position }
(PageReferent)-[:referent]->(Referent) # This is a full list, Denormalized from all of the page's content.

Partner { name, abbr, short_name, homepage_url, description, notes, links_json, repository_id, created_at, updated_at }

Rank { name }
Rank-[:treat_as]->(Rank)

Reference {}
(Content:Node)-[:reference]->(Reference)
(Reference)-[:resource]->(Resource) # Denormalized.
(Reference)-[:referent]->(Referent)

Referent { repository_id, body, created_at, updated_at }
(Referent)-[:resource]->(Resource) # Denormalized.

Resource { repository_id, name, abbr, url, description, notes, nodes_count, is_classification, is_browsable,
  node_source_url_template, last_published_at, last_publish_seconds, dataset_rights_holder, dataset_rights_statement,
  created_at, updated_at }
(Resource)-[:partner]->(Partner)
(Resource)-[:dataset_license]->(License)

Role { name, created_at, upadted_at }

// NOTE: I removed the denormalized page link we had here, I don't think we need it in the graph.
ScientificName { node_resource_pk, repository_id, italicized, canonical_form, genus, specific_epithet,
  infraspecific_epithet, infrageneric_epithet, uninomial, verbatim, authorship, publication, remarks, parse_quality,
  year, is_hybrid, is_surrogate, is_virus, attribution, created_at, updated_at }
(Node)-[:scientific_name]->(ScientificName)
(TaxonomicStatus)
(Node)-[:preferred_scientific_name]->(ScientificName)
(Node)-[:resource]->(Resource)
(Node)-[:source_reference]->(Reference)

Section { name, position }
(Content)-[:section]->(Section)
(Section)-[:parent]->(Section)

// NOTE: this was "TaxonRemarks"
Remarks { body }
(Node)-[:remarks]->(Remarks)

// TODO: I don't think we actually need all of these flags in the publishing DB, but check.
TaxonomicStatus { name, is_preferred, is_problematic, is_alternative_preferred, can_merge }

Vernacular { node_resource_pk, string, locality, created_at, updated_at }
(Vernacular)-[:language]->(Language)
(Vernacular)-[:trust]->(Trust)
(Vernacular)-[:remarks]->(Remarks)
(Vernacular)-[:source]->(Source)
(Node)-[:vernacular]->(Vernacular)
(Node)-[:preferred_vernacular]->(Vernacular)
(Page)-[:vernacular]->(Vernacular) # Denormalized. Do we need this? Not sure.
(Page)-[:preferred_vernacular]->(Vernacular)

Source { name } # TODO: Don't we use this elsewhere, too? Hmmn...
