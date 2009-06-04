module Lacuna
  class Config
    def self.defaults
    end
    
    def load_xml
      doc = REXML::Document.new(stream)
    end
    
    def apply_xml
    end
  end
end