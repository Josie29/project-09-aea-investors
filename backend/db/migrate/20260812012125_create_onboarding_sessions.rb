class CreateOnboardingSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_sessions do |t|
      # One onboarding per user. The unique index below is what makes "the current
      # user's session" a well-defined thing rather than a guess at which row to use.
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # Deliberately a string, not an integer enum. Integer-backed enums make the
      # database unreadable during an incident ("state = 3" tells you nothing) and
      # reordering the enum silently rewrites the meaning of existing rows.
      t.string :state, null: false, default: "consent"

      t.timestamps
    end

    add_index :onboarding_sessions, :state
  end
end
