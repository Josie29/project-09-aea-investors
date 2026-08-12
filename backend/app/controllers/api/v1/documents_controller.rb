module Api
  module V1
    # Upload of the user's ID document.
    #
    # Consent-gated: this is the endpoint the brief's "before any document image is
    # uploaded or processed" requirement is actually about.
    class DocumentsController < ApplicationController
      include ConsentGate

      before_action :require_active_consent!, only: :create

      def show
        document = Document.find_by(onboarding_session: current_session)
        return render json: { status: "none" }, status: :ok if document.nil?

        render json: serialize(document)
      end

      def create
        validation = DocumentImageValidator.new(params[:image]).call

        # 422 with a message the interface can show verbatim. A rejected upload must
        # never dead-end: the flow's manual-entry path stays open, so this is a
        # correctable problem rather than a failure.
        unless validation.valid?
          return render json: { error: "invalid_upload", detail: validation.error },
                        status: :unprocessable_content
        end

        document = Document.replace_for!(current_session, params[:image])

        # Queued rather than run inline: OCR takes hundreds of milliseconds and the
        # upload response should not wait on it. The interface polls the document
        # until the status leaves `pending`.
        DocumentExtractionJob.perform_later(document.id)

        render json: serialize(document), status: :created
      end

      private

      def current_session
        @current_session ||= OnboardingSession.for(current_user)
      end

      # No filename, and no signed URL unless the image is still present. The filename
      # a user's phone assigns can itself be identifying, and it is of no use to the
      # interface.
      def serialize(document)
        {
          status: document.status,
          image_available: document.image_available?,
          image_purged_at: document.image_purged_at&.iso8601,
          updated_at: document.updated_at.iso8601,
          fields: document.extracted_fields.map { |field| serialize_field(field) }
        }
      end

      # Confidence is sent to the interface deliberately: the design shows it beside
      # each field so the user can see the difference between confidently read and
      # barely guessed. `state` is computed server-side so the thresholds live in one
      # place rather than being duplicated in TypeScript and drifting.
      def serialize_field(field)
        {
          name: field.name,
          value: field.display_value,
          confidence: field.confidence.to_f,
          state: field.state,
          confirmed: field.confirmed?
        }
      end
    end
  end
end
