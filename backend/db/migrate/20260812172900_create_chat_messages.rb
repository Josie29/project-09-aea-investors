class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages do |t|
      t.references :onboarding_session, null: false, foreign_key: true

      t.string :role, null: false
      # The user's own words about their mental health. The most sensitive free text
      # in the system: it is stored because the flow needs the transcript, and it is
      # destroyed with the session on a deletion request.
      t.text :content, null: false

      # Classified intent, for user turns only. Drives supportive-content triggers and
      # the intent-coverage eval.
      t.string :intent

      t.timestamps
    end

    add_index :chat_messages, %i[onboarding_session_id created_at]
  end
end
