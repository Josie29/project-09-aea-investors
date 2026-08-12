class ExtractedField < ApplicationRecord
  # Fields the onboarding flow reads off an ID. `id_number` is captured but is not
  # one of the three the brief scores; it exists because the design shows it as the
  # example of a field left deliberately blank.
  NAMES = %w[name dob address id_number].freeze

  # Thresholds, kept here so Ruby and TypeScript agree on one source of truth. These
  # match docs/ux-decisions.md and the values the confirm screen renders.
  #
  # Below CHECK_THIS the interface flags the field for the user's attention. Below
  # PREFILL nothing is pre-filled at all: a guess presented as data is worse than an
  # empty box, because the user has no signal to correct it.
  CHECK_THIS_THRESHOLD = 0.80
  PREFILL_THRESHOLD = 0.40

  belongs_to :document

  validates :name, inclusion: { in: NAMES }, uniqueness: { scope: :document_id }
  validates :confidence, numericality: { in: 0..1 }

  # How the interface should present this field.
  #
  # @return [Symbol] :read, :check_this, or :not_found
  def state
    return :not_found if value.blank?
    return :check_this if confidence < CHECK_THIS_THRESHOLD

    :read
  end

  def confirmed?
    confirmed_at.present?
  end

  # What the user should see in the input: their own correction if they made one,
  # otherwise the machine's reading, and nothing at all if it was too uncertain.
  def display_value
    return confirmed_value if confirmed?
    return nil if confidence < PREFILL_THRESHOLD

    value
  end

  # Whether the user changed what OCR read. Feeds the correction-rate metric without
  # storing anything extra: the original read and the confirmed value are both here.
  def corrected?
    confirmed? && confirmed_value != value
  end
end
