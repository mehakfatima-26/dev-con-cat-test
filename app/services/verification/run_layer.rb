module Verification
  class RunLayer
    def initialize(verification_run:, layer_key:)
      @run = verification_run
      @layer_key = layer_key
    end

    def call
      existing = LayerResult.find_by(verification_run: run, layer_key: layer_key)

      return existing if existing && !existing.errored?

      outcome = run_adapter
      charge_credits! unless outcome[:not_applicable] || outcome[:errored]
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

    def charge_credits!
      return if CreditTransaction.exists?(idempotency_key: "#{run.id}:#{layer_key}")

      CreditTransaction.create!(
        account: run.lead.account,
        verification_run: run,
        layer_key: layer_key,
        amount: -DetectionLayer.cost(layer_key),
        idempotency_key: "#{run.id}:#{layer_key}"
      )
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
