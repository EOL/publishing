# 20170922173758
class AddFieldsForImport < ActiveRecord::Migration
  def change
    add_column :nodes, :parent_resource_pk, :string, index: true
    add_column :scientific_names, :resource_id, :integer
    add_column :scientific_names, :node_resource_pk, :string
    add_column :scientific_names, :source_reference, :string
    add_column :scientific_names, :genus, :string
    add_column :scientific_names, :specific_epithet, :string
    add_column :scientific_names, :infraspecific_epithet, :string
    add_column :scientific_names, :infrageneric_epithet, :string
    add_column :scientific_names, :uninomial, :string
    add_column :scientific_names, :verbatim, :text
    add_column :scientific_names, :authorship, :text
    add_column :scientific_names, :publication, :text
    add_column :scientific_names, :remarks, :text
    add_column :scientific_names, :parse_quality, :integer
    add_column :scientific_names, :year, :integer
    add_column :scientific_names, :hybrid, :boolean
    add_column :scientific_names, :surrogate, :boolean
    add_column :scientific_names, :virus, :boolean
    add_column :resources, :abbr, :string
    add_column :resources, :repository_id, :integer # NOTE: no need for index, never queried.
    add_column :partners, :repository_id, :integer # NOTE: no need for index, never queried.

    create_table :import_logs do |t|
      t.integer :resource_id, null: false
      t.datetime :completed_at
      t.datetime :failed_at
      t.string :status, comment: 'amounts to the last message of the log.'
      t.timestamps
    end

    create_table :import_events do |t|
      t.integer :import_log_id, null: false
      t.integer :cat, comment: 'enum: infos warnings errors starts ends urls'
      t.text :body
      t.timestamps
    end
  end
end
# The year is from GNA:
