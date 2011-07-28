require 'i18n'

module Lacuna
  def self.root
    File.expand_path('../../../', __FILE__)
  end
  
  def self.initialize!
    I18n.load_path << "#{root}/i18n/en.yml"
    I18n.load_path << "#{root}/i18n/da.yml"
    I18n.locale = 'da'
    Configuration.clear
    load("#{root}/config/defaults.rb")
    load("#{root}/config/config.rb") if File.exists?("#{root}/config/config.rb")
  end
  
  def self.paths(*args)
    configuration.paths(*args)
  end
  
  def self.programs(*args)
    configuration.programs(*args)
  end

  def self.encodings(*args)
    configuration.encodings(*args)
  end
  
  def self.configuration
    @configuration ||= Configuration.new(Lacuna::Configuration.defaults)
  end
  
  class MissingConfigKeyError < StandardError
  end
  
  class Configuration
    class Value
      def +(other)
        PlusReference.new(self, other)
      end
      
      def /(other)
        PathReference.new(self, other)
      end

      def |(other)
        SelectReference.new(self, other)
      end

      def to_s
        resolve
      end
      alias :to_str :to_s
    end
    
    class ValueReference < Value
      attr_reader :group, :key

      def initialize(group, key)
        @group, @key = group, key
      end

      def inspect
        "Ref[#{key}]"
      end
      
      def group(c=nil)
        c ? c[@group._name] : @group
      end

      def resolve(c=nil)
        group(c)._resolve(key).to_s
      end

      def valid?(c=nil)
        group(c)._valid?(key)
      end
      
      def defined?(c=nil)
        group(c)._defined?(key)
      end

      def eql?(other)
        if other.respond_to?(:group) && other.respond_to?(:key)
          group.eql?(other.group) && key.eql?(other.key)
        else
          to_str.eql?(other.to_str)
        end
      end

      def ==(other)
        if other.respond_to?(:group) && other.respond_to?(:key)
          group == other.group && key == other.key
        else
          other.respond_to?(:to_str) && to_str == other.to_str
        end
      end
    end
    
    class BinaryReference < Value
      attr_reader :first, :second
      
      def initialize(first, second)
        @first, @second = first, second
      end

      def valid?(c=nil)
        (!first.respond_to?(:valid?) || first.valid?(c)) &&
        (!second.respond_to?(:valid?) || second.valid?(c))
      end
      
      def defined?(c=nil)
        (!first.respond_to?(:defined?) || first.defined?(c)) &&
        (!second.respond_to?(:defined?) || second.defined?(c))
      end
    end
      
    class PlusReference < BinaryReference
      def inspect
        "#{first.inspect}+#{second.inspect}"
      end
      
      def resolve(c=nil)
        f, s = first, second
        f = f.resolve(c) if f.respond_to? :resolve
        s = s.resolve(c) if f.respond_to? :resolve
        f.to_s + s.to_s
      end
    end
    
    class PathReference < BinaryReference
      def inspect
        "#{first.inspect}/#{second.inspect}"
      end
      
      def resolve(c=nil)
        f, s = first, second
        f = f.resolve(c) if f.respond_to? :resolve
        s = s.resolve(c) if f.respond_to? :resolve
        f.to_s + '/' + s.to_s
      end
    end

    class SelectReference < BinaryReference
      def inspect
        "#{first.inspect}|#{second.inspect}"
      end
      
      def resolve(c=nil)
        val = first.defined?(c) ? first : second
        val = val.resolve(c) if val.respond_to? :resolve
        val.to_s
      end
    end
    
    
    class Group
      def initialize(name)
        @name = name
        @values = {}
      end
      
      def _name
        @name
      end
      
      def []=(name, value)
        @values[name.to_sym] = value
      end
      
      def [](*args)
        ret = args.map do |name|
          ValueReference.new(self, name.to_sym)
        end
        if ret.size == 1
          ret[0]
        else
          ret
        end
      end
      
      def _valid?(name)
        val = @values[name]
        !val.nil? && (!val.respond_to?(:valid?) || val.valid?)
      end
      
      def _defined?(name)
        !@values[name].nil?
      end
      
      def _lookup(name)
        @values[name]
      end
      
      def _resolve(name)
        #puts "Resolve #{name}"
        ret = @values[name]
        raise MissingConfigKeyError, "Key #{name} is missing from configuration group #{@name}" unless ret
        #puts "Resolve #{name} - ret #{ret.inspect}"
        ret
      end
      
      def method_missing(cmd, value=nil)
        if /^(.*)=$/ =~ cmd.to_s
          self[$1] = value
        else
          self[cmd]
        end
      end

      def inspect
        "Lacuna::Configuration::Group[#{@name}]"
      end
      alias :to_s :inspect
    end
    
    class ShadowGroup < Group
      def initialize(configuration, parent, name)
        @configuration, @parent = configuration, parent
        super(name)
      end
      
      def _valid?(name)
        val = @values[name] || @parent._lookup(name)
        !val.nil? && (!val.respond_to?(:valid?) || val.valid?(@configuration))
      end

      def _defined?(name)
        !@values[name].nil? || @parent._defined?(name)
      end
      
      def _resolve(name)
        #puts "ShadowResolve #{name} #{@parent}"
        name = name.to_sym
        ref = @values[name] || @parent._resolve(name)
        ref = ref.resolve(@configuration) if ref.respond_to? :resolve
        ref
      end
      
      def inspect
        "Lacuna::Configuration::ShadowGroup[#{@name}]"
      end
    end
    
    def self.defaults
      @defaults ||= Lacuna::Configuration.new
      yield @defaults if block_given?
      @defaults
    end
    
    def self.clear
      Lacuna.configuration._clear
    end
    
    def initialize(defaults=nil)
      @defaults = defaults
    end
    
    def [](*keys)
      ret = keys.map do |name|
        name = name.to_sym
        @groups ||= {}
        @groups[name] ||= @defaults ? ShadowGroup.new(self, @defaults[name], name) : Group.new(name)
      end
      if ret.size == 1
        ret[0]
      else
        ret
      end
    end
    
    def method_missing(cmd,*args)
      ret = self[cmd]
      if block_given?
        yield ret, *args
      elsif args.size > 0
        ret[*args]
      else
        ret
      end
    end
    
    def _clear
      @groups = nil
      @defaults._clear if @defaults
    end
  end
end

