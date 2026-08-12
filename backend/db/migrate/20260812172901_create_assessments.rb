class CreateAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :assessments do |t|
      t.references :onboarding_session, null: false, foreign_key: true, index: { unique: true }

      # One column per line the design shows in the summary sidebar. Explicit columns
      # rather than a JSON blob: the brief's acceptance criterion is that a structured
      # record has all required fields populated, and that is checkable here without
      # parsing anything.
      t.string :presenting_concern
      t.string :frequency
      t.string :referral
      t.string :prior_care
      t.string :modality
      t.string :urgency

      # Set when the user says the summary is right. Until then the record is the
      # machine's reading, not something a clinician should act on.
      t.datetime :acknowledged_at

      t.timestamps
    end
  end
end
