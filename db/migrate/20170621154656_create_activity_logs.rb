class CreateActivityLogs < ActiveRecord::Migration[4.2]
  def change
    create_table :collectings do |t|
      t.references :user, index: true
      t.references :collection, index: true
      t.integer :action, comment: "enum: add, change, remove"
      t.references :content, polymorphic: true, index: true
      t.references :page, index: true
      t.references :associated_collection
      t.string :changed_field
      t.text :changed_from # Overloaded with removed name in the case of action=remove
      t.text :changed_to

      t.timestamps
    end

    create_table :content_repositions do |t|
      t.references :user_id
      t.references :page_content
      t.integer :changed_from
      t.integer :changed_to

      t.timestamps
    end

    # NOTE: this one is NOT USED YET ... but I am adding it because I want to
    # capture it in the changes table without having to migrate later.
    create_table :content_edits do |t|
      t.references :user_id
      t.references :page_content
      t.string :changed_field
      t.text :changed_from
      t.text :changed_to
      t.text :comment

      t.timestamps
    end

    # NOTE: "changes" is a VERY basic changelog, and it completely denormalized;
    # it can be rebuilt simply by summing the referenced tables (grabbing the
    # id, the user_id (because we want to index that), the page_id IF THERE IS
    # ONE (again, because we want to index that), and the timestamps). ...We're
    # only using this to avoid a rather nasty UNION. The tables allowed are:

    create_table :changes do |t|
      t.references :user, index: true
      t.references :page, index: true
      t.references :activity, polymorphic: true,
        comment: "references one of the following: Collecting, Curation, "\
          "ContentReposition, ContentEdit, TraitReposition, TraitEdit. Trait "\
          "FKs refer to TraitBank, not MySQL."

      t.timestamps
    end

    # This was left off, but I'm *sure* we're going to want it:
    add_column :curations, :comment, :text
  end
end
