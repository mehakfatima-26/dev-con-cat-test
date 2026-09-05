require "rails_helper"

RSpec.describe LayerResult do
  it "has a valid factory" do
    expect(build(:layer_result)).to be_valid
  end

  it "requires layer_key" do
    expect(build(:layer_result, layer_key: nil)).not_to be_valid
  end

  it "rejects an unknown layer_key" do
    result = build(:layer_result, layer_key: "not_a_real_layer")

    expect(result).not_to be_valid
    expect(result.errors[:layer_key]).to be_present
  end

  it "accepts every known layer key" do
    DetectionLayer::KEYS.each do |key|
      expect(build(:layer_result, layer_key: key)).to be_valid
    end
  end

  it "requires a unique layer_key within the same run" do
    run = create(:verification_run)
    create(:layer_result, verification_run: run, layer_key: "anura")
    dupe = build(:layer_result, verification_run: run, layer_key: "anura")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:layer_key]).to be_present
  end

  it "allows the same layer_key across different runs" do
    create(:layer_result, layer_key: "anura")

    expect(build(:layer_result, layer_key: "anura")).to be_valid
  end

  it "exposes the five layer states" do
    expect(LayerResult.states.keys).to contain_exactly(
      "not_enabled", "not_applicable", "completed", "errored", "skipped"
    )
  end

  it "prevents destroying a verification_run that still has layer_results" do
    run = create(:verification_run)
    create(:layer_result, verification_run: run)

    expect(run.destroy).to be false
    expect(run.errors[:base]).to be_present
  end

  describe "database-level constraints (bypassing model validations)" do
    it "rejects a duplicate [verification_run_id, layer_key] at the DB level" do
      run = create(:verification_run)
      base_attrs = {
        verification_run_id: run.id, layer_key: "dnc", state: 2,
        created_at: Time.current, updated_at: Time.current
      }
      LayerResult.insert_all!([ base_attrs ])

      expect {
        LayerResult.insert_all!([ base_attrs ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
