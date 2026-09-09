module Api
  module Pixel
    class LeadsController < BaseController
      before_action :find_and_authorize_pixel!

      def create
        capture_session = pixel.capture_sessions.find_by(session_id: params[:session_id])
        return render_forbidden("no matching capture session -- call /visit first") unless capture_session

        return respond_with(capture_session.lead, status: :ok) if capture_session.lead

        if (duplicate = exact_crm_duplicate)
          return respond_rejected(duplicate)
        end

        return respond_no_credits if pixel.account.credits_remaining < critical_layers_cost

        lead = find_replayable_lead || create_lead!(capture_session)

        Verification::Runner.call(lead, async: true)

        respond_with(lead, status: :created)
      end

      private

      def fields
        params.fetch(:fields, {})
      end

      def exact_crm_duplicate
        return nil if fields[:phone].blank? || fields[:email].blank?

        Layers::DuplicateDetection.exact_match(account: pixel.account, phone: fields[:phone], email: fields[:email])
      end

      def respond_rejected(duplicate)
        render json: {
          verdict: "reject",
          score: 0.0,
          reasons: [ "Exact duplicate of existing CRM record #{duplicate.crm_id}" ]
        }, status: :ok
      end

      def critical_layers_cost
        policy_version = ConsensusPolicy.active_version_for(pixel.account)
        return 0 unless policy_version

        critical = ConsensusEngine.critical_layers_for(policy_version) & pixel.account.enabled_modules
        critical.sum { |layer_key| DetectionLayer.cost(layer_key) }
      end

      def respond_no_credits
        render json: { error: "Account does not have enough credits to run the required checks" }, status: :payment_required
      end

      def find_replayable_lead
        return nil if fields[:first_name].blank? || fields[:last_name].blank?

        pixel.account.leads.find_by(first_name: fields[:first_name], last_name: fields[:last_name])
      end

      def create_lead!(capture_session)
        Lead.create!(
          account: pixel.account, pixel: pixel, capture_session: capture_session,
          lead_id: generate_lead_id,
          first_name: fields[:first_name], last_name: fields[:last_name],
          email: fields[:email], phone: fields[:phone],
          ip_address: request.remote_ip, user_agent: request.user_agent,
          landing_page_url: capture_session.page_url,
          form_dwell_ms: params[:form_dwell_ms] || 0,
          captured_at: params[:submitted_at] || Time.current
        )
      end

      def generate_lead_id
        "L-#{SecureRandom.alphanumeric(8).upcase}"
      end

      def respond_with(lead, status:)
        payload = { lead_id: lead.lead_id, stream_token: generate_stream_token(lead) }
        prior = prior_non_accepted_attempts(lead).to_a
        payload[:prior_attempts] = { count: prior.size, verdicts: prior.first(5).map(&:verdict) } if prior.any?

        render json: payload, status: status
      end

      def prior_non_accepted_attempts(lead)
        VerificationRun.joins(:lead)
          .where(leads: { account_id: pixel.account_id, phone: lead.phone, email: lead.email })
          .where(status: %w[completed partial])
          .where.not(verdict: :accept)
          .order(created_at: :desc)
      end
    end
  end
end
