class Assessment < ApplicationRecord
  # The lines the design shows in the summary sidebar, in display order. One list
  # drives the model, the serializer, and the completeness check, so a field added
  # later cannot appear in one and be forgotten in another.
  FIELDS = {
    presenting_concern: "Presenting concern",
    frequency: "Frequency",
    referral: "Referral",
    prior_care: "Prior care",
    modality: "Modality",
    urgency: "Urgency"
  }.freeze

  belongs_to :onboarding_session

  validates :onboarding_session_id, uniqueness: true

  def self.for(session)
    find_or_create_by!(onboarding_session: session)
  rescue ActiveRecord::RecordNotUnique
    find_by!(onboarding_session: session)
  end

  # Merges newly extracted values without erasing what is already known.
  #
  # The model re-reads the whole conversation each turn and may return nothing for a
  # field it previously filled — a blank must never overwrite a real answer, or the
  # sidebar would visibly forget things the user already said.
  #
  # @param values [Hash] field name => extracted value
  def merge_extracted!(values)
    updates = FIELDS.keys.each_with_object({}) do |field, acc|
      incoming = values[field] || values[field.to_s]
      acc[field] = incoming if incoming.present?
    end

    update!(updates) if updates.any?
  end

  # Applies the user's own edits, which outrank the model's reading.
  #
  # Editing withdraws acknowledgement: what was confirmed is no longer what is on
  # screen, so the user has to look again before this leaves the step.
  def apply_edits!(values)
    permitted = values.slice(*FIELDS.keys.map(&:to_s), *FIELDS.keys)
    update!(permitted.to_h.symbolize_keys.merge(acknowledged_at: nil))
  end

  def acknowledge!
    update!(acknowledged_at: Time.current)
  end

  def acknowledged?
    acknowledged_at.present?
  end

  # @return [Array<Symbol>] fields still unanswered, so the assistant knows what to
  #   ask about next rather than repeating questions
  def outstanding_fields
    FIELDS.keys.reject { |field| public_send(field).present? }
  end

  def complete?
    outstanding_fields.empty?
  end
end
