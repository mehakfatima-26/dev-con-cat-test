module Certificates
  class Verifier
    def self.call(certificate)
      new(certificate).call
    end

    def initialize(certificate)
      @certificate = certificate
    end

    def call
      {
        valid: payload_valid? && signature_valid? && chain_valid?,
        payload_valid: payload_valid?,
        signature_valid: signature_valid?,
        chain_valid: chain_valid?
      }
    end

    private

    attr_reader :certificate

    def payload_valid?
      recomputed_payload_sha256 == certificate.payload_sha256
    end

    def signature_valid?
      recomputed_signature == certificate.signature
    end

    def chain_valid?
      if previous_certificate
        certificate.prev_sha256 == previous_certificate.payload_sha256
      else
        certificate.prev_sha256.nil?
      end
    end

    def recomputed_payload_sha256
      Digest::SHA256.hexdigest(Certificate.canonical_json(certificate.payload))
    end

    def recomputed_signature
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{certificate.payload_sha256}:#{certificate.prev_sha256}")
    end

    def previous_certificate
      @previous_certificate ||= Certificate.joins(verification_run: :lead)
        .where(leads: { account_id: certificate.account.id })
        .where("certificates.id < ?", certificate.id)
        .order(id: :desc)
        .first
    end
  end
end
