class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      # One document per session. A user re-uploading replaces the previous one, and
      # the old image is purged rather than accumulating copies of someone's ID.
      t.references :onboarding_session, null: false, foreign_key: true, index: { unique: true }

      t.string :status, null: false, default: "pending"

      # When the source image was destroyed. Kept as evidence after the image is gone,
      # so a deletion request can be shown to have been honoured — the confirmation
      # screen shows the user this timestamp.
      t.datetime :image_purged_at

      t.timestamps
    end

    add_index :documents, :status
  end
end
