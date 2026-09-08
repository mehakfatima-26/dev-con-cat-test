class PixelsController < ApplicationController
  before_action :require_account!

  def show
    @pixel = Current.account.pixel

    if @pixel
      authorize @pixel
    else
      skip_authorization
      redirect_to new_pixel_path
    end
  end

  def new
    @pixel = Current.account.pixel || Current.account.build_pixel

    if @pixel.persisted?
      skip_authorization
      redirect_to pixel_path
    else
      authorize @pixel, :create?
    end
  end

  def create
    @pixel = Current.account.build_pixel(pixel_params.merge(pixel_id: generate_pixel_id))
    authorize @pixel, :create?

    if @pixel.save
      redirect_to pixel_path, notice: "Pixel created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_account!
    redirect_to root_path, alert: "Not available for this account." if Current.account.blank?
  end

  def pixel_params
    permitted = params.require(:pixel).permit(:name, :allowed_origins)
    permitted[:allowed_origins] = permitted[:allowed_origins].to_s.split(/[\n,]/).map(&:strip).reject(&:empty?)
    permitted
  end

  def generate_pixel_id
    "px_#{SecureRandom.hex(6)}"
  end
end
