module PixelsHelper
  def pixel_snippet(pixel)
    <<~SNIPPET.strip
      <script async src="#{pixel_script_url}"
              data-pixel-id="#{pixel.pixel_id}"
              data-endpoint="#{pixel_endpoint_url}"></script>
    SNIPPET
  end

  private

  def pixel_script_url
    "#{root_url}super-pixel.js"
  end

  def pixel_endpoint_url
    "#{root_url}api/pixel"
  end
end
