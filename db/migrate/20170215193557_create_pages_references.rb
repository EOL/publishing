class CreatePagesReferences < ActiveRecord::Migration
  def change
    # rename_table :references, :referents
    # rename_table :articles_references, :references
    # add_column :references, :parent_type, :string, default: "Article", null: false
    # remove_index :references, column: :article_id
    # rename_column :references, :article_id, :parent_id
    # rename_column :references, :reference_id, :referent_id
    # reversible do |dir|
    #   change_table :references do |t|
    #     dir.up   do
    #       t.change :parent_type, :string, default: nil, null: false
    #     end
    #     dir.down do
    #       # No need to do anthing.
    #     end
    #   end
    # end
    # add_index(:references, [:parent_type, :parent_id],
    #   name: "references_by_parent_index")
    # create_join_table(:pages, :referents) do |t|
    #   t.index :page_id
    #   t.integer :position
    # end
    reversible do |dir|
      dir.up do
        # NOTE: you cannot use find_each here because this table has no PK. This is
        # fine for our purposes, since there aren't many in the DB when this
        # migration was written. (In fact, there are none in my DB. Sigh.)
        Reference.all.each do |ref|
          if ref.parent
            ref.parent.pages.each do |page|
              page.referents << ref.referent
            end
          end
        end
      end
      dir.down do
        # Again, nothing required.
      end
    end
  end
end
