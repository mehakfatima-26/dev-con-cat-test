module Providers
  class FixtureData
    DIR = Rails.root.join("mock-data/providers")

    def self.for(provider_key, lead_id)
      file(provider_key)["results"][lead_id]
    end

    def self.file(provider_key)
      @files ||= {}
      @files[provider_key] ||= JSON.parse(DIR.join("#{provider_key}.json").read)
    end
  end
end
