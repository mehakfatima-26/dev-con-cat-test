module Api
  module Pixel
    class ActivitiesController < BaseController
      include ActionController::Live

      def show
        lead = lead_from_stream_token(params[:token])
        return render_forbidden("invalid or expired token") unless lead && lead.lead_id == params[:lead_id]
        return render_forbidden("origin not allowed") unless allowed_origin?(lead.pixel)

        stream_activity(lead)
      ensure
        response.stream.close
      end

      private

      def stream_activity(lead)
        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Accel-Buffering"] = "no"

        run = lead.verification_run
        sent_ids = []
        redis = Verification::ActivityPublisher.new_subscriber_connection

        redis.subscribe(Verification::ActivityPublisher.channel_for(lead)) do |on|
          on.subscribe do |_channel, _count|
            flush_existing(run, sent_ids)
            finish_if_already_done(run, redis)
          end

          on.message do |_channel, message|
            handle_message(JSON.parse(message), sent_ids, redis)
          end
        end
      ensure
        redis&.close
      end

      def flush_existing(run, sent_ids)
        run.layer_results.where.not(id: sent_ids).order(:created_at).find_each do |result|
          write_layer_result(result)
          sent_ids << result.id
        end
      end

      def finish_if_already_done(run, redis)
        run.reload
        return unless run.status.in?(%w[completed partial])

        write_final_verdict(run)
        redis.unsubscribe
      end

      def handle_message(event, sent_ids, redis)
        case event["type"]
        when "layer_result"
          return if sent_ids.include?(event["id"])

          write_event("layer_result", layer: event["layer"], verdict: event["verdict"], detail: event["detail"])
          sent_ids << event["id"]
        when "final_verdict"
          write_event("final_verdict", verdict: event["verdict"], score: event["score"], reasons: event["reasons"])
          redis.unsubscribe
        end
      end

      def write_layer_result(result)
        write_event("layer_result", layer: result.layer_key, verdict: result.result || result.state, detail: result.detail)
      end

      def write_final_verdict(run)
        write_event("final_verdict", verdict: run.verdict, score: run.score, reasons: run.reasons)
      end

      def write_event(name, data)
        response.stream.write("event: #{name}\n")
        response.stream.write("data: #{data.to_json}\n\n")
      rescue IOError
        throw :abort
      end
    end
  end
end
