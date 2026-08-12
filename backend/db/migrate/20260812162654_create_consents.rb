class CreateConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :consents do |t|
      t.references :onboarding_session, null: false, foreign_key: true, index: { unique: true }

      # Both timestamps are the audit log. The brief requires consent to be logged and
      # revocation to be logged; keeping them as two columns on one row means the
      # record cannot exist in a state where a grant has no time or a withdrawal
      # leaves no trace.
      t.datetime :granted_at, null: false
      t.datetime :withdrawn_at

      # What they agreed to. Without this, a later change to the privacy notice makes
      # every stored consent unfalsifiable — you know they agreed, not to what.
      t.string :policy_version, null: false

      t.timestamps
    end

    # Deliberately NOT stored: IP address and user agent. Both are personal data, and
    # the flow's premise is collecting only what it needs. A timestamped record tied
    # to an authenticated session already establishes who consented and when.

    add_index :consents, :withdrawn_at
  end
end
