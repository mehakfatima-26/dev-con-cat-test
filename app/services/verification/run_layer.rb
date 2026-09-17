module Verification
  class RunLayer
    def initialize(verification_run:, layer_key:)
      @run = verification_run
      @layer_key = layer_key
    end

    def call
      existing = LayerResult.find_by(verification_run: run, layer_key: layer_key)

      return existing if existing && !existing.errored?

      first_resolution = existing.nil?

      outcome = run_adapter
      outcome = insufficient_credits_outcome unless outcome[:not_applicable] || outcome[:errored] || charge_credits!
      release_reservation if first_resolution && critical?
      persist(outcome, existing)
    end

    private

    attr_reader :run, :layer_key

    def adapter_class
      "Layers::#{layer_key.camelize}".constantize
    end

    def run_adapter
      adapter_class.new(run.lead, provider_rules).call
    rescue StandardError, NotImplementedError => e
      { errored: true, detail: "#{layer_key} failed: #{e.message}" }
    end

    def insufficient_credits_outcome
      { errored: true, detail: "#{layer_key} not run: insufficient credits" }
    end

    def critical?
      ConsensusEngine.critical_layers_for(run.policy_version).include?(layer_key)
    end

    # Releases this layer's own slice of the run's reservation the moment its fate is
    # decided (charged, errored, or not_applicable) -- otherwise a layer that resolves
    # early still holds its full share locked up for the rest of the run, double-counting
    # against a sibling lead once this layer is *also* charged for real. Clamped at zero
    # since nothing here depends on credits_reserved having been sized correctly upstream.
    def release_reservation
      cost = DetectionLayer.cost(layer_key)
      run.update!(credits_reserved: [ run.credits_reserved - cost, 0 ].max)
    end

    def charge_credits!
      return true if CreditTransaction.exists?(idempotency_key: idempotency_key)

      account = run.lead.account
      charged = false

      account.with_lock do
        next if CreditTransaction.exists?(idempotency_key: idempotency_key)
        next if account.credits_remaining(excluding_run: run) < DetectionLayer.cost(layer_key)

        CreditTransaction.create!(
          account: account,
          verification_run: run,
          layer_key: layer_key,
          amount: -DetectionLayer.cost(layer_key),
          idempotency_key: idempotency_key
        )
        charged = true
      end

      charged
    end

    def idempotency_key
      "#{run.id}:#{layer_key}"
    end

    def provider_rules
      run.policy_version.rules[layer_key] || {}
    end

    def persist(outcome, existing)
      state = if outcome[:not_applicable]
        :not_applicable
      elsif outcome[:errored]
        :errored
      else
        :completed
      end

      attrs = {
        state: state, result: outcome[:result], detail: outcome[:detail],
        raw_response: outcome[:raw], weight: outcome[:weight]
      }

      if existing
        existing.update!(attrs)
        existing
      else
        LayerResult.create!(verification_run: run, layer_key: layer_key, **attrs)
      end
    end
  end
end
