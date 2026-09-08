class LeadsController < ApplicationController
  def index
    @q = params[:q].to_s.strip
    @verdict = params[:verdict].presence

    @leads = policy_scope(Lead).includes(:account, :pixel, verification_runs: :certificate).order(captured_at: :desc)
    @leads = search(@leads)
    @leads = @leads.select { |lead| lead.verification_run&.verdict == @verdict } if @verdict
  end

  def show
    @lead = policy_scope(Lead).find(params[:id])
    authorize @lead

    @run = @lead.verification_run
    @layer_results = @run ? @run.layer_results.index_by(&:layer_key) : {}
    @certificate = @run&.certificate
  end

  private

  def search(scope)
    return scope if @q.blank?

    term = "%#{@q}%"
    scope.where(
      "lead_id ILIKE :t OR first_name ILIKE :t OR last_name ILIKE :t OR email ILIKE :t OR phone ILIKE :t",
      t: term
    )
  end
end
