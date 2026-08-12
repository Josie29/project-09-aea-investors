require "rails_helper"

RSpec.describe "Bookings" do
  before { stub_clerk_jwks }

  def headers_for(clerk_id)
    auth_headers(clerk_token({ "sub" => clerk_id }))
  end

  let!(:slot) do
    AppointmentSlot.create!(starts_at: 3.days.from_now, clinician_name: "Dr. Amara Osei", modality: "video")
  end

  describe "GET /api/v1/appointment_slots" do
    it "lists upcoming slots" do
      get "/api/v1/appointment_slots", headers: headers_for("user_alice")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["slots"].first["clinician_name"]).to eq("Dr. Amara Osei")
    end

    # The design shows a claimed slot struck through rather than vanishing, so a user
    # who was looking at it understands why it is gone instead of watching the grid
    # silently reflow under them.
    it "still lists a taken slot, marked as taken" do
      get "/api/v1/booking", headers: headers_for("user_bob")
      post "/api/v1/booking", params: { appointment_slot_id: slot.id }, headers: headers_for("user_bob")

      get "/api/v1/appointment_slots", headers: headers_for("user_alice")

      expect(response.parsed_body["slots"].first["taken"]).to be(true)
    end

    it "omits slots in the past" do
      AppointmentSlot.create!(starts_at: 2.days.ago, clinician_name: "Dr. Past", modality: "video")

      get "/api/v1/appointment_slots", headers: headers_for("user_alice")

      expect(response.parsed_body["slots"].map { |s| s["clinician_name"] }).not_to include("Dr. Past")
    end

    it "requires authentication, so the clinic's calendar is not scrapeable" do
      get "/api/v1/appointment_slots"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/booking" do
    it "books an open slot" do
      post "/api/v1/booking", params: { appointment_slot_id: slot.id }, headers: headers_for("user_alice")

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["clinician_name"]).to eq("Dr. Amara Osei")
    end

    # The brief states it outright: a double-booking of the same slot is rejected.
    it "rejects a second user taking the same slot" do
      post "/api/v1/booking", params: { appointment_slot_id: slot.id }, headers: headers_for("user_alice")

      post "/api/v1/booking", params: { appointment_slot_id: slot.id }, headers: headers_for("user_bob")

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]).to eq("slot_unavailable")
    end

    # The two conflicts need different words in the UI: one is bad news, the other is
    # reassurance that nothing is wrong.
    it "distinguishes 'already taken' from 'you already booked'" do
      post "/api/v1/booking", params: { appointment_slot_id: slot.id }, headers: headers_for("user_alice")
      other = AppointmentSlot.create!(starts_at: 4.days.from_now, clinician_name: "Dr. Two", modality: "video")

      post "/api/v1/booking", params: { appointment_slot_id: other.id }, headers: headers_for("user_alice")

      expect(response.parsed_body["detail"]).to include('already have an appointment')
    end

    it "refuses a slot in the past" do
      past = AppointmentSlot.create!(starts_at: 1.hour.ago, clinician_name: "Dr. Past", modality: "video")

      post "/api/v1/booking", params: { appointment_slot_id: past.id }, headers: headers_for("user_alice")

      expect(response).to have_http_status(:conflict)
    end

    it "404s for a slot that does not exist" do
      post "/api/v1/booking", params: { appointment_slot_id: 999_999 }, headers: headers_for("user_alice")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/booking" do
    # Booking must survive closing the tab, or the confirmation screen has nothing to
    # show a user who comes back later.
    it "returns the booking across sessions" do
      post "/api/v1/booking", params: { appointment_slot_id: slot.id }, headers: headers_for("user_alice")

      get "/api/v1/booking", headers: headers_for("user_alice")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["starts_at"]).to be_present
    end

    it "does not leak another user's booking" do
      post "/api/v1/booking", params: { appointment_slot_id: slot.id }, headers: headers_for("user_alice")

      get "/api/v1/booking", headers: headers_for("user_bob")

      expect(response).to have_http_status(:not_found)
    end
  end
end
