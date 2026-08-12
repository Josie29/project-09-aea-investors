module Api
  module V1
    # The assessment conversation.
    class ChatController < ApplicationController
      include ConsentGate

      # The conversation is where the user describes their mental health, so it sits
      # behind the same consent gate as the document upload.
      before_action :require_active_consent!, only: :create

      def show
        render json: {
          messages: current_session.chat_messages.chronological.map { |m| serialize_message(m) },
          assessment: serialize_assessment(Assessment.for(current_session))
        }
      end

      def create
        content = params[:content].to_s.strip
        if content.blank?
          return render json: { error: "empty_message" }, status: :unprocessable_content
        end

        result = Chat::Respond.new(current_session).call(content)

        render json: {
          messages: [ serialize_message(result.user_message), serialize_message(result.assistant_message) ],
          assessment: serialize_assessment(result.assessment),
          # Tells the interface to offer the short form. The conversation still
          # continues; this is a degraded turn, not a broken session.
          degraded: result.degraded?
        }, status: :created
      end

      private

      def current_session
        @current_session ||= OnboardingSession.for(current_user)
      end

      def serialize_message(message)
        {
          id: message.id,
          role: message.role,
          content: message.content,
          intent: message.intent,
          created_at: message.created_at.iso8601
        }
      end

      def serialize_assessment(assessment)
        {
          fields: Assessment::FIELDS.map do |key, label|
            { name: key, label: label, value: assessment.public_send(key) }
          end,
          complete: assessment.complete?,
          acknowledged: assessment.acknowledged?
        }
      end
    end
  end
end
