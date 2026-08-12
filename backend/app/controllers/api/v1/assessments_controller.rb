module Api
  module V1
    # The structured summary the conversation produces.
    #
    # Separate from the chat endpoint because editing and acknowledging the summary
    # are user actions on a record, not turns in a conversation.
    class AssessmentsController < ApplicationController
      def update
        assessment = Assessment.for(current_session)
        assessment.apply_edits!(edit_params)

        render json: serialize(assessment)
      end

      # The gate described in docs/ux-decisions.md: the summary is machine-written, so
      # it needs the same confirm-before-save treatment the OCR fields get. There is
      # no separate review screen; this is that step.
      def acknowledge
        assessment = Assessment.for(current_session)
        assessment.acknowledge!

        render json: serialize(assessment)
      end

      private

      def current_session
        @current_session ||= OnboardingSession.for(current_user)
      end

      def edit_params
        params.fetch(:assessment, {}).permit(*Assessment::FIELDS.keys)
      end

      def serialize(assessment)
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
