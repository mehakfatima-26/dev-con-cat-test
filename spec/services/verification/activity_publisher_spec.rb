require "rails_helper"

RSpec.describe Verification::ActivityPublisher do
  def captured_payload
    published = nil
    redis_double = instance_double(Redis)
    allow(redis_double).to receive(:publish) { |_channel, message| published = JSON.parse(message) }
    allow(Sidekiq).to receive(:redis).and_yield(redis_double)

    yield

    published
  end

  it "includes the certificate's serial in the final_verdict payload" do
    run = create(:verification_run, :completed)
    certificate = create(:certificate, verification_run: run)

    payload = captured_payload { described_class.publish_final_verdict(run, certificate) }

    expect(payload["type"]).to eq("final_verdict")
    expect(payload["certificate_serial"]).to eq(certificate.serial)
  end

  it "omits the certificate serial (rather than erroring) when there is no certificate" do
    run = create(:verification_run, :completed)

    payload = captured_payload { described_class.publish_final_verdict(run, nil) }

    expect(payload["certificate_serial"]).to be_nil
  end
end
