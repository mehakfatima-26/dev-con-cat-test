module DetectionLayer
  CATALOG = YAML.load_file(Rails.root.join("config/detection_layers.yml")).freeze
  KEYS = CATALOG.keys.freeze

  def self.cost(layer_key)
    CATALOG.fetch(layer_key)
  end
end
