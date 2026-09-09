module Layers
  class Dnc < Base
    KEY = "dnc"

    def call
      _field, hit = find_hard_stop
      return fail_result("DNC status is #{hit}") if hit

      return pass_result(callable_detail) if fixture["dnc_status"] == "callable"

      warn_result(unrecognized(fixture["dnc_status"]), 0.0)
    end

    private

    def callable_detail
      detail = "DNC status is callable"
      detail += ", callback window is open" if fixture["callback_window_open"]
      detail
    end
  end
end
