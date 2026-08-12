class CreateExtractedFields < ActiveRecord::Migration[8.1]
  def change
    create_table :extracted_fields do |t|
      t.references :document, null: false, foreign_key: true

      t.string :name, null: false

      # What OCR read. Nullable on purpose: a field below the pre-fill threshold is
      # stored with NO value rather than a low-confidence guess, which is what lets
      # the interface show it blank as "not found" instead of asking the user to
      # approve something the machine invented.
      t.string :value

      # 0.00 to 1.00. Decimal rather than float so a threshold comparison means the
      # same thing in Postgres, Ruby, and the TypeScript that renders the chip.
      t.decimal :confidence, precision: 4, scale: 3, null: false, default: 0

      # What the user actually approved, which may differ from `value` — the whole
      # point of the confirmation step. Kept separate so the original read survives
      # for the OCR-correction-rate metric the brief asks for.
      t.string :confirmed_value
      t.datetime :confirmed_at

      t.timestamps
    end

    # One row per field per document.
    add_index :extracted_fields, %i[document_id name], unique: true
  end
end
