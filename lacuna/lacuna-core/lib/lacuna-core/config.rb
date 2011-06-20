module Lacuna
  class DefaultConfiguration
    def paths
      @paths ||= Paths.new
      yield @paths if block_given?
      @paths
    end
    
    def programs
      @programs ||= Paths.new
      yield @programs if block_given?
      @programs
    end
    
    class Paths
      def initialize
        @paths = Hash.new
      end
      
      def [](key)
        @paths[key.to_sym] ||= PathRef.new(self,key)
      end
      
      def []=(key,value)
        raise ArgumentError if value.nil?
        self[key.to_sym].value = value
      end
      
      def method_missing(cmd, value=nil)
        super unless cmd =~ /$\w(\w|\d|_)*=?^/
        if cmd[-1..-1] == '='
          self[cmd] = value
        else
          self[cmd]
        end
      end
    end
    
    class PathRef
      def initialize(owner, key)
        @owner = owner
        @key = key.to_sym
      end
      
      def /(other)
        PathTemplate.new(self,other)
      end
      
      def value=(o)
        @value = o
      end
      
      def to_s
        @value.to_s
      end
    end

    class PathTemplate
      def initialize(*elements)
        @elements = elements
      end
      
      def /(other)
        elements = @elements.dup
        elements.push other
        PathTemplate.new(*elements)
      end
      
      def to_s
        @elements.map{|e| e.to_s}.join('/')
      end
    end
  end
  
  class Config
    def self.defaults
      @defaults ||= DefaultConfiguration.new
      yield @defaults if block_given?
    end
    
    def self.load_yml
      doc = REXML::Document.new()
      interfaces = doc.element('network')
      certs = doc.element('certificates')
    end
    
    def apply_xml
    end
  end
end