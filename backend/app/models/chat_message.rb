class ChatMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  # The intent list the brief requires the chatbot to handle, plus the fallback.
  # `out_of_scope` is a first-class outcome rather than a failure: the acceptance
  # criterion is that unrecognised input gets a graceful answer, not an error.
  INTENTS = %w[provide_details ask_question request_reschedule express_distress out_of_scope].freeze

  belongs_to :onboarding_session

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true
  validates :intent, inclusion: { in: INTENTS }, allow_nil: true

  scope :chronological, -> { order(:created_at, :id) }

  def user? = role == "user"

  # Shape the LLM client expects, for replaying the conversation as context.
  def to_prompt_message
    { role: role, content: content }
  end
end
