class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Clerk's `sub` claim. This is the ONLY identity field stored locally: Clerk
      # owns email, name, and credentials, so keeping a copy here would duplicate
      # PII into a second system for no benefit and widen the deletion surface.
      t.string :clerk_id, null: false

      t.timestamps
    end

    # Unique so a race between the wizard's parallel first requests cannot create
    # two rows for one person; the model rescues the resulting RecordNotUnique.
    add_index :users, :clerk_id, unique: true
  end
end
