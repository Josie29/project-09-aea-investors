require "rails_helper"

RSpec.describe Assessment do
  subject(:assessment) { described_class.for(session) }

  let(:session) { OnboardingSession.for(create(:user)) }

  describe "#merge_extracted!" do
    # The model re-reads the whole conversation each turn and may return nothing for
    # a field it filled earlier. If a blank overwrote a real answer, the sidebar
    # would visibly forget things the user already told it.
    it "never lets a blank erase a value already known" do
      assessment.merge_extracted!(presenting_concern: "Panic attacks")

      assessment.merge_extracted!(presenting_concern: nil, frequency: "Twice a week")

      expect(assessment.presenting_concern).to eq("Panic attacks")
      expect(assessment.frequency).to eq("Twice a week")
    end

    it "accepts string keys, since they arrive as parsed JSON" do
      assessment.merge_extracted!("referral" => "GP")

      expect(assessment.referral).to eq("GP")
    end

    it "ignores keys that are not assessment fields" do
      expect { assessment.merge_extracted!("diagnosis" => "made up") }.not_to raise_error
    end
  end

  describe "#apply_edits!" do
    # Per docs/ux-decisions.md: editing withdraws acknowledgement, because what was
    # confirmed is no longer what is on screen.
    it "withdraws acknowledgement when the user changes a line" do
      assessment.acknowledge!

      assessment.apply_edits!("presenting_concern" => "Corrected by hand")

      expect(assessment).not_to be_acknowledged
      expect(assessment.presenting_concern).to eq("Corrected by hand")
    end
  end

  describe "completeness" do
    it "lists what is still outstanding so the assistant asks about the right thing" do
      assessment.merge_extracted!(presenting_concern: "Panic attacks")

      expect(assessment.outstanding_fields).to include(:frequency, :urgency)
      expect(assessment.outstanding_fields).not_to include(:presenting_concern)
    end

    it "is complete only once every line has an answer" do
      described_class::FIELDS.each_key { |f| assessment.merge_extracted!(f => "answered") }

      expect(assessment).to be_complete
    end
  end
end
