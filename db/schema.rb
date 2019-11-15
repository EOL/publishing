# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20191109201943) do

  create_table "articles", force: :cascade do |t|
    t.string   "guid",                      limit: 255,        null: false
    t.string   "resource_pk",               limit: 255
    t.integer  "license_id",                limit: 4,          null: false
    t.integer  "language_id",               limit: 4
    t.integer  "location_id",               limit: 4
    t.integer  "stylesheet_id",             limit: 4
    t.integer  "javascript_id",             limit: 4
    t.integer  "bibliographic_citation_id", limit: 4
    t.text     "owner",                     limit: 65535
    t.string   "name",                      limit: 255
    t.string   "source_url",                limit: 4096
    t.text     "body",                      limit: 4294967295
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.integer  "resource_id",               limit: 4
    t.string   "rights_statement",          limit: 1024
    t.integer  "page_id",                   limit: 4
    t.integer  "harv_db_id",                limit: 4
  end

  add_index "articles", ["guid"], name: "index_articles_on_guid", using: :btree
  add_index "articles", ["harv_db_id"], name: "index_articles_on_harv_db_id", using: :btree
  add_index "articles", ["resource_id"], name: "index_articles_on_resource_id", using: :btree

  create_table "articles_collected_pages", id: false, force: :cascade do |t|
    t.integer "collected_page_id", limit: 4, null: false
    t.integer "article_id",        limit: 4, null: false
    t.integer "position",          limit: 4
  end

  add_index "articles_collected_pages", ["collected_page_id"], name: "index_articles_collected_pages_on_collected_page_id", using: :btree

  create_table "attributions", force: :cascade do |t|
    t.integer  "content_id",          limit: 4
    t.string   "content_type",        limit: 255,   null: false
    t.integer  "role_id",             limit: 4,     null: false
    t.text     "value",               limit: 65535, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "url",                 limit: 512
    t.integer  "resource_id",         limit: 4,     null: false
    t.string   "resource_pk",         limit: 255
    t.string   "content_resource_fk", limit: 255,   null: false
  end

  add_index "attributions", ["content_type", "content_id"], name: "index_attributions_on_content_type_and_content_id", using: :btree
  add_index "attributions", ["resource_id"], name: "index_attributions_on_resource_id", using: :btree

  create_table "bibliographic_citations", force: :cascade do |t|
    t.integer  "resource_id", limit: 4,     null: false
    t.text     "body",        limit: 65535
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "harv_db_id",  limit: 4
  end

  add_index "bibliographic_citations", ["harv_db_id"], name: "index_bibliographic_citations_on_harv_db_id", using: :btree

  create_table "changes", force: :cascade do |t|
    t.integer  "user_id",       limit: 4
    t.integer  "page_id",       limit: 4
    t.integer  "activity_id",   limit: 4
    t.string   "activity_type", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "changes", ["page_id"], name: "index_changes_on_page_id", using: :btree
  add_index "changes", ["user_id"], name: "index_changes_on_user_id", using: :btree

  create_table "collected_pages", force: :cascade do |t|
    t.integer  "collection_id", limit: 4,     null: false
    t.integer  "page_id",       limit: 4,     null: false
    t.integer  "position",      limit: 4
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.text     "annotation",    limit: 65535
  end

  add_index "collected_pages", ["collection_id", "page_id"], name: "enforce_unique_pairs", unique: true, using: :btree
  add_index "collected_pages", ["collection_id"], name: "index_collected_pages_on_collection_id", using: :btree
  add_index "collected_pages", ["page_id"], name: "index_collected_pages_on_page_id", using: :btree

  create_table "collected_pages_links", id: false, force: :cascade do |t|
    t.integer "collected_page_id", limit: 4, null: false
    t.integer "link_id",           limit: 4, null: false
    t.integer "position",          limit: 4
  end

  add_index "collected_pages_links", ["collected_page_id"], name: "index_collected_pages_links_on_collected_page_id", using: :btree

  create_table "collected_pages_media", id: false, force: :cascade do |t|
    t.integer "collected_page_id", limit: 4, null: false
    t.integer "medium_id",         limit: 4, null: false
    t.integer "position",          limit: 4
  end

  add_index "collected_pages_media", ["collected_page_id"], name: "index_collected_pages_media_on_collected_page_id", using: :btree

  create_table "collectings", force: :cascade do |t|
    t.integer  "user_id",                  limit: 4
    t.integer  "collection_id",            limit: 4
    t.integer  "action",                   limit: 4
    t.integer  "content_id",               limit: 4
    t.string   "content_type",             limit: 255
    t.integer  "page_id",                  limit: 4
    t.integer  "associated_collection_id", limit: 4
    t.string   "changed_field",            limit: 255
    t.text     "changed_from",             limit: 65535
    t.text     "changed_to",               limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "collectings", ["collection_id"], name: "index_collectings_on_collection_id", using: :btree
  add_index "collectings", ["content_type", "content_id"], name: "index_collectings_on_content_type_and_content_id", using: :btree
  add_index "collectings", ["page_id"], name: "index_collectings_on_page_id", using: :btree
  add_index "collectings", ["user_id"], name: "index_collectings_on_user_id", using: :btree

  create_table "collection_associations", force: :cascade do |t|
    t.integer  "collection_id", limit: 4,     null: false
    t.integer  "position",      limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "associated_id", limit: 4
    t.text     "annotation",    limit: 65535
  end

  add_index "collection_associations", ["collection_id"], name: "index_collection_associations_on_collection_id", using: :btree

  create_table "collections", force: :cascade do |t|
    t.string   "name",                          limit: 255,               null: false
    t.text     "description",                   limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "collected_pages_count",         limit: 4,     default: 0
    t.integer  "collection_associations_count", limit: 4,     default: 0
    t.integer  "collection_type",               limit: 4,     default: 0
    t.integer  "default_sort",                  limit: 4,     default: 0
    t.integer  "v2_id",                         limit: 4
  end

  create_table "collections_users", id: false, force: :cascade do |t|
    t.integer  "user_id",       limit: 4,                 null: false
    t.integer  "collection_id", limit: 4,                 null: false
    t.boolean  "is_manager",              default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "collections_users", ["collection_id"], name: "index_collections_users_on_collection_id", using: :btree
  add_index "collections_users", ["user_id"], name: "index_collections_users_on_user_id", using: :btree

  create_table "content_edits", force: :cascade do |t|
    t.integer  "user_id_id",      limit: 4
    t.integer  "page_content_id", limit: 4
    t.string   "changed_field",   limit: 255
    t.text     "changed_from",    limit: 65535
    t.text     "changed_to",      limit: 65535
    t.text     "comment",         limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "content_repositions", force: :cascade do |t|
    t.integer  "user_id_id",      limit: 4
    t.integer  "page_content_id", limit: 4
    t.integer  "changed_from",    limit: 4
    t.integer  "changed_to",      limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "content_sections", force: :cascade do |t|
    t.integer "section_id",   limit: 4,   null: false
    t.integer "content_id",   limit: 4,   null: false
    t.string  "content_type", limit: 255, null: false
    t.integer "resource_id",  limit: 4,   null: false
  end

  add_index "content_sections", ["content_type", "content_id"], name: "index_content_sections_on_content_type_and_content_id", using: :btree

  create_table "crono_jobs", force: :cascade do |t|
    t.string   "job_id",            limit: 255,        null: false
    t.text     "log",               limit: 4294967295
    t.datetime "last_performed_at"
    t.boolean  "healthy"
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
  end

  add_index "crono_jobs", ["job_id"], name: "index_crono_jobs_on_job_id", unique: true, using: :btree

  create_table "curations", force: :cascade do |t|
    t.integer  "user_id",              limit: 4,                     null: false
    t.integer  "page_content_id",      limit: 4,                     null: false
    t.integer  "trust",                limit: 4,     default: 0,     null: false
    t.boolean  "is_incorrect",                       default: false, null: false
    t.boolean  "is_misidentified",                   default: false, null: false
    t.boolean  "is_hidden",                          default: false, null: false
    t.boolean  "is_duplicate",                       default: false, null: false
    t.boolean  "is_low_quality",                     default: false, null: false
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.integer  "old_trust",            limit: 4,     default: 0,     null: false
    t.boolean  "old_is_incorrect",                   default: false, null: false
    t.boolean  "old_is_misidentified",               default: false, null: false
    t.boolean  "old_is_hidden",                      default: false, null: false
    t.boolean  "old_is_duplicate",                   default: false, null: false
    t.boolean  "old_is_low_quality",                 default: false, null: false
    t.text     "comment",              limit: 65535
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   limit: 4,     default: 0, null: false
    t.integer  "attempts",   limit: 4,     default: 0, null: false
    t.text     "handler",    limit: 65535,             null: false
    t.text     "last_error", limit: 65535
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by",  limit: 255
    t.string   "queue",      limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "home_page_feed_items", force: :cascade do |t|
    t.string   "img_url",           limit: 255
    t.string   "link_url",          limit: 255
    t.string   "label",             limit: 255
    t.text     "desc",              limit: 65535
    t.integer  "home_page_feed_id", limit: 4
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.integer  "feed_version",      limit: 4
    t.integer  "page_id",           limit: 4
  end

  add_index "home_page_feed_items", ["home_page_feed_id", "feed_version"], name: "index_home_page_feed_items_on_home_page_feed_id_and_feed_version", using: :btree

  create_table "home_page_feeds", force: :cascade do |t|
    t.string   "name",              limit: 255
    t.integer  "field_mask",        limit: 4
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.integer  "published_version", limit: 4,   default: 0
  end

  create_table "identifiers", force: :cascade do |t|
    t.integer "resource_id",      limit: 4,   null: false
    t.integer "node_id",          limit: 4
    t.string  "node_resource_pk", limit: 255, null: false
    t.string  "identifier",       limit: 255
    t.integer "harv_db_id",       limit: 4
  end

  add_index "identifiers", ["node_id"], name: "index_identifiers_on_node_id", using: :btree
  add_index "identifiers", ["node_resource_pk"], name: "index_identifiers_on_node_resource_pk", using: :btree
  add_index "identifiers", ["resource_id"], name: "index_identifiers_on_resource_id", using: :btree

  create_table "image_info", force: :cascade do |t|
    t.integer  "resource_id",   limit: 4,                           null: false
    t.integer  "medium_id",     limit: 4,                           null: false
    t.string   "original_size", limit: 12,                          null: false
    t.string   "large_size",    limit: 12
    t.string   "medium_size",   limit: 12
    t.string   "small_size",    limit: 12
    t.decimal  "crop_x",                    precision: 5, scale: 2
    t.decimal  "crop_y",                    precision: 5, scale: 2
    t.decimal  "crop_w",                    precision: 5, scale: 2
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
    t.string   "resource_pk",   limit: 255
    t.integer  "harv_db_id",    limit: 4
  end

  add_index "image_info", ["harv_db_id"], name: "index_image_info_on_harv_db_id", using: :btree
  add_index "image_info", ["medium_id"], name: "index_image_info_on_medium_id", using: :btree
  add_index "image_info", ["resource_id"], name: "index_image_info_on_resource_id", using: :btree
  add_index "image_info", ["resource_pk"], name: "index_image_info_on_resource_pk", using: :btree

  create_table "import_events", force: :cascade do |t|
    t.integer  "import_log_id", limit: 4,     null: false
    t.integer  "cat",           limit: 4
    t.text     "body",          limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "import_logs", force: :cascade do |t|
    t.integer  "resource_id",  limit: 4,   null: false
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.string   "status",       limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "import_runs", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "javascripts", force: :cascade do |t|
    t.integer "resource_id", limit: 4,   null: false
    t.string  "filename",    limit: 255, null: false
  end

  create_table "languages", force: :cascade do |t|
    t.string  "code",            limit: 12,                 null: false
    t.string  "group",           limit: 12,                 null: false
    t.boolean "can_browse_site",            default: false, null: false
  end

  add_index "languages", ["code"], name: "index_languages_on_code", using: :btree
  add_index "languages", ["group"], name: "index_languages_on_group", using: :btree

  create_table "license_group_includes", force: :cascade do |t|
    t.integer "this_id",     limit: 4
    t.integer "includes_id", limit: 4
  end

  add_index "license_group_includes", ["includes_id"], name: "index_license_group_includes_on_includes_id", using: :btree
  add_index "license_group_includes", ["this_id", "includes_id"], name: "index_license_group_includes_on_this_id_and_includes_id", unique: true, using: :btree
  add_index "license_group_includes", ["this_id"], name: "index_license_group_includes_on_this_id", using: :btree

  create_table "license_groups", force: :cascade do |t|
    t.string "key", limit: 255
  end

  add_index "license_groups", ["key"], name: "index_license_groups_on_key", using: :btree

  create_table "license_groups_licenses", force: :cascade do |t|
    t.integer "license_id",       limit: 4
    t.integer "license_group_id", limit: 4
  end

  add_index "license_groups_licenses", ["license_group_id"], name: "index_license_groups_licenses_on_license_group_id", using: :btree
  add_index "license_groups_licenses", ["license_id", "license_group_id"], name: "index_license_groups_licenses_on_license_id_and_license_group_id", unique: true, using: :btree
  add_index "license_groups_licenses", ["license_id"], name: "index_license_groups_licenses_on_license_id", using: :btree

  create_table "licenses", force: :cascade do |t|
    t.string   "name",                      limit: 255,                 null: false
    t.string   "source_url",                limit: 255
    t.string   "icon_url",                  limit: 255
    t.boolean  "can_be_chosen_by_partners",             default: false, null: false
    t.datetime "created_at",                                            null: false
    t.datetime "updated_at",                                            null: false
  end

  create_table "links", force: :cascade do |t|
    t.string   "guid",             limit: 255,   null: false
    t.string   "resource_pk",      limit: 255
    t.integer  "language_id",      limit: 4
    t.string   "name",             limit: 255
    t.string   "source_url",       limit: 4096
    t.text     "description",      limit: 65535, null: false
    t.string   "icon_url",         limit: 255,   null: false
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.integer  "resource_id",      limit: 4
    t.string   "rights_statement", limit: 1024
    t.integer  "page_id",          limit: 4
  end

  add_index "links", ["guid"], name: "index_links_on_guid", using: :btree

  create_table "locations", force: :cascade do |t|
    t.integer "resource_id",      limit: 4,                               null: false
    t.string  "location",         limit: 255
    t.decimal "longitude",                      precision: 64, scale: 12
    t.decimal "latitude",                       precision: 64, scale: 12
    t.decimal "altitude",                       precision: 64, scale: 12
    t.text    "spatial_location", limit: 65535
  end

  create_table "media", force: :cascade do |t|
    t.string   "guid",                      limit: 255,               null: false
    t.string   "resource_pk",               limit: 255
    t.integer  "subclass",                  limit: 4,     default: 0, null: false
    t.integer  "format",                    limit: 4,     default: 0, null: false
    t.integer  "license_id",                limit: 4,                 null: false
    t.integer  "language_id",               limit: 4
    t.integer  "location_id",               limit: 4
    t.integer  "stylesheet_id",             limit: 4
    t.integer  "javascript_id",             limit: 4
    t.integer  "bibliographic_citation_id", limit: 4
    t.text     "owner",                     limit: 65535
    t.string   "name",                      limit: 255
    t.string   "source_url",                limit: 4096
    t.text     "description",               limit: 65535
    t.string   "base_url",                  limit: 255,               null: false
    t.datetime "created_at",                                          null: false
    t.datetime "updated_at",                                          null: false
    t.string   "unmodified_url",            limit: 255
    t.string   "source_page_url",           limit: 4096
    t.integer  "resource_id",               limit: 4,                 null: false
    t.string   "rights_statement",          limit: 1024
    t.integer  "page_id",                   limit: 4
    t.string   "usage_statement",           limit: 255
    t.integer  "harv_db_id",                limit: 4
  end

  add_index "media", ["guid"], name: "index_media_on_guid", using: :btree
  add_index "media", ["harv_db_id"], name: "index_media_on_harv_db_id", using: :btree
  add_index "media", ["resource_id"], name: "index_media_on_resource_id", using: :btree
  add_index "media", ["resource_pk"], name: "index_media_on_resource_pk", using: :btree
  add_index "media", ["subclass"], name: "index_media_on_subclass", using: :btree

  create_table "node_ancestors", force: :cascade do |t|
    t.integer "resource_id",          limit: 4,   null: false
    t.integer "node_id",              limit: 4
    t.integer "ancestor_id",          limit: 4
    t.string  "node_resource_pk",     limit: 255
    t.string  "ancestor_resource_pk", limit: 255
    t.integer "depth",                limit: 4
    t.integer "harv_db_id",           limit: 4
  end

  add_index "node_ancestors", ["ancestor_id"], name: "index_node_ancestors_on_ancestor_id", using: :btree
  add_index "node_ancestors", ["ancestor_resource_pk"], name: "index_node_ancestors_on_ancestor_resource_pk", using: :btree
  add_index "node_ancestors", ["harv_db_id"], name: "index_node_ancestors_on_harv_db_id", using: :btree
  add_index "node_ancestors", ["node_id"], name: "index_node_ancestors_on_node_id", using: :btree
  add_index "node_ancestors", ["node_resource_pk"], name: "index_node_ancestors_on_node_resource_pk", using: :btree
  add_index "node_ancestors", ["resource_id"], name: "index_node_ancestors_on_resource_id", using: :btree

  create_table "nodes", force: :cascade do |t|
    t.integer  "resource_id",        limit: 4,                    null: false
    t.integer  "page_id",            limit: 4
    t.integer  "rank_id",            limit: 4
    t.integer  "parent_id",          limit: 4
    t.string   "scientific_name",    limit: 255
    t.string   "canonical_form",     limit: 255
    t.string   "resource_pk",        limit: 255,                  null: false
    t.string   "source_url",         limit: 4096
    t.boolean  "is_hidden",                       default: false, null: false
    t.boolean  "in_unmapped_area",                default: false, null: false
    t.integer  "children_count",     limit: 4,    default: 0,     null: false
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.boolean  "has_breadcrumb",                  default: true
    t.string   "parent_resource_pk", limit: 255
    t.integer  "landmark",           limit: 4,    default: 0
    t.integer  "harv_db_id",         limit: 4
  end

  add_index "nodes", ["harv_db_id"], name: "index_nodes_on_harv_db_id", using: :btree
  add_index "nodes", ["page_id"], name: "index_nodes_on_page_id", using: :btree
  add_index "nodes", ["parent_id"], name: "index_nodes_on_parent_id", using: :btree
  add_index "nodes", ["resource_id"], name: "index_nodes_on_resource_id", using: :btree
  add_index "nodes", ["resource_pk"], name: "index_nodes_on_resource_pk", using: :btree

  create_table "occurrence_maps", force: :cascade do |t|
    t.integer "resource_id", limit: 4
    t.integer "page_id",     limit: 4
    t.string  "url",         limit: 256
  end

  create_table "open_authentications", force: :cascade do |t|
    t.string   "provider",   limit: 255, null: false
    t.string   "uid",        limit: 255, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.integer  "user_id",    limit: 4
  end

  add_index "open_authentications", ["user_id"], name: "index_open_authentications_on_user_id", using: :btree

  create_table "page_contents", force: :cascade do |t|
    t.integer  "page_id",                      limit: 4,                   null: false
    t.integer  "resource_id",                  limit: 4,                   null: false
    t.integer  "source_page_id",               limit: 4,                   null: false
    t.integer  "position",                     limit: 4
    t.integer  "content_id",                   limit: 4,                   null: false
    t.string   "content_type",                 limit: 255,                 null: false
    t.integer  "association_added_by_user_id", limit: 4
    t.integer  "trust",                        limit: 4,   default: 1,     null: false
    t.boolean  "is_incorrect",                             default: false, null: false
    t.boolean  "is_misidentified",                         default: false, null: false
    t.boolean  "is_hidden",                                default: false, null: false
    t.boolean  "is_duplicate",                             default: false, null: false
    t.boolean  "is_low_quality",                           default: false, null: false
    t.datetime "created_at",                                               null: false
    t.datetime "updated_at",                                               null: false
  end

  add_index "page_contents", ["content_id"], name: "index_page_contents_on_content_id", using: :btree
  add_index "page_contents", ["content_type", "content_id"], name: "index_page_contents_on_content_type_and_content_id", using: :btree
  add_index "page_contents", ["page_id", "content_type", "content_id"], name: "effective_pk", unique: true, using: :btree
  add_index "page_contents", ["page_id", "content_type", "position"], name: "contents_for_page_index", using: :btree
  add_index "page_contents", ["page_id", "content_type"], name: "page_content_by_type_index", using: :btree
  add_index "page_contents", ["page_id", "position"], name: "page_id_by_position", using: :btree
  add_index "page_contents", ["page_id"], name: "index_page_contents_on_page_id", using: :btree
  add_index "page_contents", ["source_page_id"], name: "index_page_contents_on_source_page_id", using: :btree

  create_table "page_desc_infos", force: :cascade do |t|
    t.integer  "page_id",       limit: 4
    t.integer  "species_count", limit: 4
    t.integer  "genus_count",   limit: 4
    t.integer  "family_count",  limit: 4
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "page_icons", force: :cascade do |t|
    t.integer  "page_id",    limit: 4
    t.integer  "user_id",    limit: 4
    t.integer  "medium_id",  limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "page_icons", ["medium_id"], name: "index_page_icons_on_medium_id", using: :btree
  add_index "page_icons", ["page_id"], name: "index_page_icons_on_page_id", using: :btree
  add_index "page_icons", ["user_id"], name: "index_page_icons_on_user_id", using: :btree

  create_table "page_redirects", force: :cascade do |t|
    t.integer "redirect_to_id", limit: 4
  end

  create_table "pages", force: :cascade do |t|
    t.integer  "native_node_id",         limit: 4
    t.integer  "moved_to_page_id",       limit: 4
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.integer  "page_contents_count",    limit: 4,   default: 0,     null: false
    t.integer  "media_count",            limit: 4,   default: 0,     null: false
    t.integer  "articles_count",         limit: 4,   default: 0,     null: false
    t.integer  "links_count",            limit: 4,   default: 0,     null: false
    t.integer  "maps_count",             limit: 4,   default: 0,     null: false
    t.integer  "nodes_count",            limit: 4,   default: 0,     null: false
    t.integer  "vernaculars_count",      limit: 4,   default: 0,     null: false
    t.integer  "scientific_names_count", limit: 4,   default: 0,     null: false
    t.integer  "referents_count",        limit: 4,   default: 0,     null: false
    t.integer  "species_count",          limit: 4,   default: 0,     null: false
    t.boolean  "is_extinct",                         default: false, null: false
    t.boolean  "is_marine",                          default: false, null: false
    t.boolean  "has_checked_extinct",                default: false, null: false
    t.boolean  "has_checked_marine",                 default: false, null: false
    t.string   "iucn_status",            limit: 255
    t.string   "trophic_strategy",       limit: 255
    t.string   "geographic_context",     limit: 255
    t.string   "habitat",                limit: 255
    t.integer  "page_richness",          limit: 4
    t.integer  "medium_id",              limit: 4
  end

  create_table "pages_referents", id: false, force: :cascade do |t|
    t.integer "page_id",     limit: 4, null: false
    t.integer "referent_id", limit: 4, null: false
    t.integer "position",    limit: 4
  end

  add_index "pages_referents", ["page_id"], name: "index_pages_referents_on_page_id", using: :btree

  create_table "partners", force: :cascade do |t|
    t.string   "name",          limit: 255,   null: false
    t.string   "abbr",          limit: 16
    t.string   "short_name",    limit: 255,   null: false
    t.string   "homepage_url",  limit: 255
    t.text     "description",   limit: 65535
    t.text     "notes",         limit: 65535
    t.text     "links_json",    limit: 65535
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.integer  "repository_id", limit: 4
  end

  create_table "partners_users", id: false, force: :cascade do |t|
    t.integer "partner_id", limit: 4, null: false
    t.integer "user_id",    limit: 4, null: false
  end

  create_table "processes", force: :cascade do |t|
    t.integer  "resource_id", limit: 4,     null: false
    t.string   "error",       limit: 255
    t.text     "trace",       limit: 65535
    t.datetime "created_at"
    t.datetime "stopped_at"
  end

  create_table "ranks", force: :cascade do |t|
    t.string  "name",     limit: 255, null: false
    t.integer "treat_as", limit: 4
  end

  create_table "references", id: false, force: :cascade do |t|
    t.integer "parent_id",   limit: 4,                       null: false
    t.integer "referent_id", limit: 4,                       null: false
    t.string  "parent_type", limit: 255, default: "Article", null: false
    t.integer "resource_id", limit: 4,                       null: false
    t.integer "id",          limit: 4,                       null: false
  end

  add_index "references", ["parent_type", "parent_id"], name: "references_by_parent_index", using: :btree
  add_index "references", ["resource_id"], name: "index_references_on_resource_id", using: :btree

  create_table "referents", force: :cascade do |t|
    t.text     "body",        limit: 65535
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "resource_id", limit: 4,     null: false
    t.integer  "harv_db_id",  limit: 4
  end

  add_index "referents", ["harv_db_id"], name: "index_referents_on_harv_db_id", using: :btree
  add_index "referents", ["resource_id"], name: "index_referents_on_resource_id", using: :btree

  create_table "refinery_image_translations", force: :cascade do |t|
    t.integer  "refinery_image_id", limit: 4,   null: false
    t.string   "locale",            limit: 255, null: false
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.string   "image_alt",         limit: 255
    t.string   "image_title",       limit: 255
  end

  add_index "refinery_image_translations", ["locale"], name: "index_refinery_image_translations_on_locale", using: :btree
  add_index "refinery_image_translations", ["refinery_image_id"], name: "index_refinery_image_translations_on_refinery_image_id", using: :btree

  create_table "refinery_images", force: :cascade do |t|
    t.string   "image_mime_type", limit: 255
    t.string   "image_name",      limit: 255
    t.integer  "image_size",      limit: 4
    t.integer  "image_width",     limit: 4
    t.integer  "image_height",    limit: 4
    t.string   "image_uid",       limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.string   "image_title",     limit: 255
    t.string   "image_alt",       limit: 255
  end

  create_table "refinery_page_part_translations", force: :cascade do |t|
    t.integer  "refinery_page_part_id", limit: 4,     null: false
    t.string   "locale",                limit: 255,   null: false
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.text     "body",                  limit: 65535
  end

  add_index "refinery_page_part_translations", ["locale"], name: "index_refinery_page_part_translations_on_locale", using: :btree
  add_index "refinery_page_part_translations", ["refinery_page_part_id"], name: "index_refinery_page_part_translations_on_refinery_page_part_id", using: :btree

  create_table "refinery_page_parts", force: :cascade do |t|
    t.integer  "refinery_page_id", limit: 4
    t.string   "slug",             limit: 255
    t.text     "body",             limit: 65535
    t.integer  "position",         limit: 4
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "title",            limit: 255
  end

  add_index "refinery_page_parts", ["id"], name: "index_refinery_page_parts_on_id", using: :btree
  add_index "refinery_page_parts", ["refinery_page_id"], name: "index_refinery_page_parts_on_refinery_page_id", using: :btree

  create_table "refinery_page_translations", force: :cascade do |t|
    t.integer  "refinery_page_id", limit: 4,   null: false
    t.string   "locale",           limit: 255, null: false
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.string   "title",            limit: 255
    t.string   "custom_slug",      limit: 255
    t.string   "menu_title",       limit: 255
    t.string   "slug",             limit: 255
  end

  add_index "refinery_page_translations", ["locale"], name: "index_refinery_page_translations_on_locale", using: :btree
  add_index "refinery_page_translations", ["refinery_page_id"], name: "index_refinery_page_translations_on_refinery_page_id", using: :btree

  create_table "refinery_pages", force: :cascade do |t|
    t.integer  "parent_id",           limit: 4
    t.string   "path",                limit: 255
    t.string   "slug",                limit: 255
    t.string   "custom_slug",         limit: 255
    t.boolean  "show_in_menu",                     default: true
    t.string   "link_url",            limit: 4096
    t.string   "menu_match",          limit: 255
    t.boolean  "deletable",                        default: true
    t.boolean  "draft",                            default: false
    t.boolean  "skip_to_first_child",              default: false
    t.integer  "lft",                 limit: 4
    t.integer  "rgt",                 limit: 4
    t.integer  "depth",               limit: 4
    t.string   "view_template",       limit: 255
    t.string   "layout_template",     limit: 255
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
    t.boolean  "show_date"
  end

  add_index "refinery_pages", ["depth"], name: "index_refinery_pages_on_depth", using: :btree
  add_index "refinery_pages", ["id"], name: "index_refinery_pages_on_id", using: :btree
  add_index "refinery_pages", ["lft"], name: "index_refinery_pages_on_lft", using: :btree
  add_index "refinery_pages", ["parent_id"], name: "index_refinery_pages_on_parent_id", using: :btree
  add_index "refinery_pages", ["rgt"], name: "index_refinery_pages_on_rgt", using: :btree

  create_table "refinery_resource_translations", force: :cascade do |t|
    t.integer  "refinery_resource_id", limit: 4,   null: false
    t.string   "locale",               limit: 255, null: false
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.string   "resource_title",       limit: 255
  end

  add_index "refinery_resource_translations", ["locale"], name: "index_refinery_resource_translations_on_locale", using: :btree
  add_index "refinery_resource_translations", ["refinery_resource_id"], name: "index_refinery_resource_translations_on_refinery_resource_id", using: :btree

  create_table "refinery_resources", force: :cascade do |t|
    t.string   "file_mime_type", limit: 255
    t.string   "file_name",      limit: 255
    t.integer  "file_size",      limit: 4
    t.string   "file_uid",       limit: 255
    t.string   "file_ext",       limit: 255
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  create_table "resource_preferences", force: :cascade do |t|
    t.integer "resource_id", limit: 4,   null: false
    t.string  "class_name",  limit: 255, null: false
    t.integer "position",    limit: 4,   null: false
  end

  add_index "resource_preferences", ["class_name"], name: "index_resource_preferences_on_class_name", using: :btree

  create_table "resources", force: :cascade do |t|
    t.integer  "partner_id",               limit: 4,                     null: false
    t.string   "name",                     limit: 255,                   null: false
    t.string   "url",                      limit: 255
    t.text     "description",              limit: 65535
    t.text     "notes",                    limit: 65535
    t.integer  "nodes_count",              limit: 4
    t.boolean  "is_browsable",                           default: false, null: false
    t.boolean  "has_duplicate_nodes",                    default: false, null: false
    t.string   "node_source_url_template", limit: 4096
    t.datetime "last_published_at"
    t.integer  "last_publish_seconds",     limit: 4
    t.integer  "dataset_license_id",       limit: 4
    t.string   "dataset_rights_holder",    limit: 255
    t.string   "dataset_rights_statement", limit: 255
    t.datetime "created_at",                                             null: false
    t.datetime "updated_at",                                             null: false
    t.string   "abbr",                     limit: 255
    t.integer  "repository_id",            limit: 4
    t.boolean  "classification",                         default: false
  end

  add_index "resources", ["partner_id"], name: "index_resources_on_partner_id", using: :btree

  create_table "roles", force: :cascade do |t|
    t.string   "name",       limit: 255, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "scientific_names", force: :cascade do |t|
    t.integer  "node_id",               limit: 4,                    null: false
    t.integer  "page_id",               limit: 4,                    null: false
    t.string   "italicized",            limit: 255,                  null: false
    t.string   "canonical_form",        limit: 255,                  null: false
    t.integer  "taxonomic_status_id",   limit: 4,                    null: false
    t.boolean  "is_preferred",                        default: true, null: false
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.integer  "resource_id",           limit: 4
    t.string   "node_resource_pk",      limit: 255
    t.string   "source_reference",      limit: 255
    t.string   "genus",                 limit: 255
    t.string   "specific_epithet",      limit: 255
    t.string   "infraspecific_epithet", limit: 255
    t.string   "infrageneric_epithet",  limit: 255
    t.string   "uninomial",             limit: 255
    t.text     "verbatim",              limit: 65535
    t.text     "authorship",            limit: 65535
    t.text     "publication",           limit: 65535
    t.text     "remarks",               limit: 65535
    t.integer  "parse_quality",         limit: 4
    t.integer  "year",                  limit: 4
    t.boolean  "hybrid"
    t.boolean  "surrogate"
    t.boolean  "virus"
    t.text     "attribution",           limit: 65535
    t.integer  "harv_db_id",            limit: 4
    t.text     "dataset_name",          limit: 65535
    t.text     "name_according_to",     limit: 65535
  end

  add_index "scientific_names", ["canonical_form"], name: "index_scientific_names_on_canonical_form", using: :btree
  add_index "scientific_names", ["harv_db_id"], name: "index_scientific_names_on_harv_db_id", using: :btree
  add_index "scientific_names", ["node_id"], name: "index_scientific_names_on_node_id", using: :btree
  add_index "scientific_names", ["page_id"], name: "index_scientific_names_on_page_id", using: :btree
  add_index "scientific_names", ["resource_id"], name: "index_scientific_names_on_resource_id", using: :btree

  create_table "search_suggestions", force: :cascade do |t|
    t.integer "page_id",       limit: 4
    t.integer "synonym_of_id", limit: 4
    t.string  "match",         limit: 255,   null: false
    t.string  "object_term",   limit: 255
    t.string  "path",          limit: 255
    t.text    "wkt_string",    limit: 65535
  end

  create_table "section_parents", force: :cascade do |t|
    t.integer "section_id", limit: 4
    t.integer "parent_id",  limit: 4
  end

  create_table "sections", force: :cascade do |t|
    t.integer "position", limit: 4
    t.string  "name",     limit: 255, null: false
  end

  create_table "seo_meta", force: :cascade do |t|
    t.integer  "seo_meta_id",      limit: 4
    t.string   "seo_meta_type",    limit: 255
    t.string   "browser_title",    limit: 255
    t.text     "meta_description", limit: 65535
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "seo_meta", ["id"], name: "index_seo_meta_on_id", using: :btree
  add_index "seo_meta", ["seo_meta_id", "seo_meta_type"], name: "id_type_index_on_seo_meta", using: :btree

  create_table "stylesheets", force: :cascade do |t|
    t.integer "resource_id", limit: 4,   null: false
    t.string  "filename",    limit: 255, null: false
  end

  create_table "tasks", force: :cascade do |t|
    t.integer  "process_id", limit: 4
    t.string   "method",     limit: 255
    t.text     "info",       limit: 65535
    t.string   "progress",   limit: 255
    t.string   "summary",    limit: 255
    t.datetime "created_at"
    t.datetime "exited_at"
  end

  create_table "taxon_remarks", force: :cascade do |t|
    t.integer "node_id", limit: 4
    t.text    "body",    limit: 65535
  end

  add_index "taxon_remarks", ["node_id"], name: "index_taxon_remarks_on_node_id", using: :btree

  create_table "taxonomic_statuses", force: :cascade do |t|
    t.string  "name",                     limit: 255,                 null: false
    t.boolean "is_preferred",                         default: true,  null: false
    t.boolean "is_problematic",                       default: false, null: false
    t.boolean "is_alternative_preferred",             default: false, null: false
    t.boolean "can_merge",                            default: true,  null: false
  end

  create_table "term_queries", force: :cascade do |t|
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.integer  "clade_id",    limit: 4
    t.integer  "result_type", limit: 4
  end

  create_table "term_query_filters", force: :cascade do |t|
    t.integer "term_query_id",          limit: 4
    t.string  "pred_uri",               limit: 255
    t.string  "obj_uri",                limit: 255
    t.string  "units_uri",              limit: 255
    t.float   "num_val1",               limit: 24
    t.float   "num_val2",               limit: 24
    t.integer "op",                     limit: 4
    t.string  "sex_uri",                limit: 255
    t.string  "lifestage_uri",          limit: 255
    t.string  "statistical_method_uri", limit: 255
    t.integer "resource_id",            limit: 4
  end

  add_index "term_query_filters", ["term_query_id"], name: "index_term_query_filters_on_term_query_id", using: :btree

  create_table "term_query_numeric_filters", force: :cascade do |t|
    t.float    "value",         limit: 24
    t.integer  "op",            limit: 4
    t.string   "units_uri",     limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "pred_uri",      limit: 255
    t.integer  "term_query_id", limit: 4
  end

  create_table "term_query_object_term_filters", force: :cascade do |t|
    t.string   "obj_uri",       limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "pred_uri",      limit: 255
    t.integer  "term_query_id", limit: 4
  end

  create_table "term_query_predicate_filters", force: :cascade do |t|
    t.integer  "term_query_id", limit: 4
    t.string   "pred_uri",      limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "term_query_predicate_filters", ["term_query_id"], name: "index_term_query_predicate_filters_on_term_query_id", using: :btree

  create_table "term_query_range_filters", force: :cascade do |t|
    t.float    "from_value",    limit: 24
    t.float    "to_value",      limit: 24
    t.string   "units_uri",     limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "pred_uri",      limit: 255
    t.integer  "term_query_id", limit: 4
  end

  create_table "user_download_errors", force: :cascade do |t|
    t.string   "message",          limit: 255
    t.text     "backtrace",        limit: 65535
    t.integer  "user_download_id", limit: 4
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "user_download_errors", ["user_download_id"], name: "index_user_download_errors_on_user_download_id", using: :btree

  create_table "user_downloads", force: :cascade do |t|
    t.integer  "user_id",       limit: 4
    t.integer  "count",         limit: 4
    t.string   "filename",      limit: 255
    t.datetime "completed_at"
    t.datetime "expired_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "term_query_id", limit: 4
    t.text     "search_url",    limit: 65535
    t.integer  "status",        limit: 4,     default: 0
  end

  add_index "user_downloads", ["term_query_id"], name: "index_user_downloads_on_term_query_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                       limit: 255,   default: ""
    t.string   "encrypted_password",          limit: 255,   default: ""
    t.string   "reset_password_token",        limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",               limit: 4,     default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",          limit: 255
    t.string   "last_sign_in_ip",             limit: 255
    t.string   "confirmation_token",          limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email",           limit: 255
    t.datetime "created_at",                                             null: false
    t.datetime "updated_at",                                             null: false
    t.string   "username",                    limit: 255,                null: false
    t.string   "name",                        limit: 255
    t.boolean  "active"
    t.string   "api_key",                     limit: 255
    t.string   "tag_line",                    limit: 255
    t.text     "bio",                         limit: 65535
    t.string   "provider",                    limit: 255
    t.string   "uid",                         limit: 255
    t.datetime "deleted_at"
    t.integer  "failed_attempts",             limit: 4,     default: 0,  null: false
    t.string   "unlock_token",                limit: 255
    t.datetime "locked_at"
    t.integer  "role",                        limit: 4,     default: 10, null: false
    t.integer  "language_id",                 limit: 4
    t.boolean  "disable_email_notifications"
    t.text     "v2_ids",                      limit: 65535
    t.integer  "curator_level",               limit: 4
    t.integer  "breadcrumb_type",             limit: 4
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["unlock_token"], name: "index_users_on_unlock_token", unique: true, using: :btree

  create_table "v2_users", force: :cascade do |t|
    t.integer "user_id", limit: 4, null: false
  end

  create_table "vernacular_preferences", force: :cascade do |t|
    t.integer  "user_id",          limit: 4,   null: false
    t.integer  "vernacular_id",    limit: 4,   null: false
    t.integer  "resource_id",      limit: 4,   null: false
    t.integer  "language_id",      limit: 4
    t.integer  "page_id",          limit: 4
    t.integer  "overridden_by_id", limit: 4
    t.string   "string",           limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "vernacular_preferences", ["page_id", "language_id"], name: "override_lookup", using: :btree
  add_index "vernacular_preferences", ["resource_id"], name: "index_vernacular_preferences_on_resource_id", using: :btree
  add_index "vernacular_preferences", ["vernacular_id"], name: "index_vernacular_preferences_on_vernacular_id", using: :btree

  create_table "vernaculars", force: :cascade do |t|
    t.string   "string",                   limit: 255,                   null: false
    t.integer  "language_id",              limit: 4,                     null: false
    t.integer  "node_id",                  limit: 4,                     null: false
    t.integer  "page_id",                  limit: 4,                     null: false
    t.boolean  "is_preferred",                           default: false, null: false
    t.boolean  "is_preferred_by_resource",               default: false, null: false
    t.datetime "created_at",                                             null: false
    t.datetime "updated_at",                                             null: false
    t.integer  "trust",                    limit: 4,     default: 0,     null: false
    t.string   "node_resource_pk",         limit: 255
    t.string   "locality",                 limit: 255
    t.text     "remarks",                  limit: 65535
    t.text     "source",                   limit: 65535
    t.integer  "resource_id",              limit: 4
    t.integer  "harv_db_id",               limit: 4
    t.integer  "user_id",                  limit: 4
  end

  add_index "vernaculars", ["harv_db_id"], name: "index_vernaculars_on_harv_db_id", using: :btree
  add_index "vernaculars", ["node_id"], name: "index_vernaculars_on_node_id", using: :btree
  add_index "vernaculars", ["page_id", "language_id"], name: "preferred_names_index", using: :btree
  add_index "vernaculars", ["page_id"], name: "index_vernaculars_on_page_id", using: :btree
  add_index "vernaculars", ["resource_id"], name: "index_vernaculars_on_resource_id", using: :btree

  create_table "warnings", force: :cascade do |t|
    t.integer "resource_id", limit: 4,   null: false
    t.string  "message",     limit: 255
  end

end
