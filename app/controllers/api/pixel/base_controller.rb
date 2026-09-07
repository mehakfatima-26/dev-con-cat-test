module Api
  module Pixel
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable

      private

      attr_reader :pixel

      def find_and_authorize_pixel!
        @pixel = ::Pixel.active.find_by(pixel_id: params[:pixel_id])
        return render_forbidden("unknown or inactive pixel") unless @pixel

        render_forbidden("origin not allowed") unless allowed_origin?(@pixel)
      end

      def allowed_origin?(pixel)
        origin = request.headers["Origin"].presence || request.base_url
        pixel.allowed_origins.include?(origin)
      end

      def stream_verifier
        Rails.application.message_verifier(:pixel_activity_stream)
      end

      def generate_stream_token(lead)
        stream_verifier.generate(lead.id, expires_in: 1.hour)
      end

      def lead_from_stream_token(token)
        ::Lead.find(stream_verifier.verify(token))
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
        nil
      end

      def render_forbidden(reason)
        render json: { error: reason }, status: :forbidden
      end

      def render_not_found
        render json: { error: "not found" }, status: :not_found
      end

      def render_unprocessable(exception)
        render json: { error: exception.record.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
