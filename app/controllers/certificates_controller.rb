class CertificatesController < ActionController::Base
  def show
    @certificate = Certificate.find_by(serial: params[:serial])
    return render_not_found unless @certificate

    @check = Certificates::Verifier.call(@certificate)

    respond_to do |format|
      format.html
      format.json { render json: json_body }
    end
  end

  private

  def render_not_found
    respond_to do |format|
      format.html { render plain: "Certificate not found", status: :not_found }
      format.json { render json: { error: "not found" }, status: :not_found }
    end
  end

  def json_body
    {
      serial: @certificate.serial,
      valid: @check[:valid],
      payload_valid: @check[:payload_valid],
      signature_valid: @check[:signature_valid],
      chain_valid: @check[:chain_valid],
      incomplete: @certificate.incomplete,
      incomplete_reason: @certificate.incomplete_reason,
      issued_at: @certificate.issued_at,
      payload: @certificate.payload
    }
  end
end
