require "rails_helper"

RSpec.describe Ocr::FieldExtractor do
  # Builds OCR output without running Tesseract, so these test the mapping logic
  # rather than the engine. Engine behaviour is covered by the golden-set eval.
  def lines_from(rows)
    rows.each_with_index.map do |(text, confidence), index|
      text.split.map do |word|
        Ocr::Engine::Word.new(text: word, confidence: confidence, line_id: "1-1-1-#{index}")
      end
    end
  end

  let(:clean_card) do
    lines_from([
      [ "NAME", 96 ],
      [ "Marisol A. Reyes", 95 ],
      [ "DOB", 96 ],
      [ "1991-03-14", 94 ],
      [ "ADDRESS", 95 ],
      [ "1420 W Fulton St", 93 ],
      [ "Chicago, IL 60607", 92 ]
    ])
  end

  it "reads the labelled fields" do
    fields = described_class.new(clean_card).call

    expect(fields[:name].value).to eq("Marisol A. Reyes")
    expect(fields[:dob].value).to eq("1991-03-14")
    expect(fields[:address].value).to eq("1420 W Fulton St, Chicago, IL 60607")
  end

  # The portrait placeholder sits beside the field column and every segmentation mode
  # we tried merges it into whichever line it aligns with. Left in, the confirm screen
  # would ask the user to approve "PHOTO Marisol A. Reyes" as their legal name.
  it "strips card furniture that OCR merges into a value" do
    merged = lines_from([ [ "NAME", 96 ], [ "PHOTO Marisol A. Reyes", 95 ] ])

    expect(described_class.new(merged).call[:name].value).to eq("Marisol A. Reyes")
  end

  # Confidence drives whether the UI flags a field for the user to check. A mean would
  # let four confident words hide one garbled character -- which is precisely the case
  # the confirm screen exists to catch.
  it "reports the weakest word's confidence, not the average" do
    mixed = [ [
      Ocr::Engine::Word.new(text: "NAME", confidence: 96, line_id: "1-1-1-0")
    ], [
      Ocr::Engine::Word.new(text: "Marisol", confidence: 98, line_id: "1-1-1-1"),
      Ocr::Engine::Word.new(text: "Reyes", confidence: 41, line_id: "1-1-1-1")
    ] ]

    expect(described_class.new(mixed).call[:name].confidence).to eq(0.41)
  end

  it "ignores Tesseract's -1 placeholder rather than scoring it as no confidence" do
    words = [ [
      Ocr::Engine::Word.new(text: "NAME", confidence: 96, line_id: "1-1-1-0")
    ], [
      Ocr::Engine::Word.new(text: "Reyes", confidence: 90, line_id: "1-1-1-1"),
      Ocr::Engine::Word.new(text: " ", confidence: Ocr::Engine::NO_CONFIDENCE, line_id: "1-1-1-1")
    ] ]

    expect(described_class.new(words).call[:name].confidence).to eq(0.90)
  end

  # A field with no readable caption must come back empty so the UI can leave it blank
  # and say "not found". Guessing here is the failure the brief calls out by name.
  it "returns nothing for a field whose caption never appeared" do
    fields = described_class.new(lines_from([ [ "NAME", 90 ], [ "Marisol A. Reyes", 88 ] ])).call

    expect(fields[:address].value).to be_nil
    expect(fields[:address].confidence).to eq(0.0)
  end

  # The DOB caption is three characters and degrades to "D0B" or "DQB" readily. The
  # value beside it is often perfectly legible, and making the user retype a date we
  # actually read would be a self-inflicted wound.
  it "recovers a date whose caption was misread" do
    mangled = lines_from([ [ "D0B", 40 ], [ "1991-03-14", 94 ] ])

    expect(described_class.new(mangled).call[:dob].value).to eq("1991-03-14")
  end
end
