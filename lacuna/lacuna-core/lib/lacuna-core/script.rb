require 'set'

module Lacuna
  class Script
    def restart(*args)
      stop *args
      start *args
    end

    def usage
      puts "#{$0} [" + self.class.cmds.to_a.join('|') + "]"
      exit 1
    end
    
    def log(msg)
      $stdout.print msg + "...  "
      $stdout.flush
      yield
      $stdout.puts "OK"
    rescue
      $stdout.puts "FAILED"
      raise
    end

    class << self
      def start(&block)   cmd :start, &block end
      def stop(&block)    cmd :stop, &block end
      def status(&block)  cmd :status, &block end
      def restart(&block) cmd :restart, &block end
      def usage(&block)   cmd :usage, &block end
    
      def cmds
        @cmds ||= {}.to_set
      end
    
      def cmd(name, &block)
        cmds << name.to_sym
        define_method name, &block
      end
      
      def run!
        #Lacuna.load
        script = Script.new
        cmd = ARGV.shift || 'status'
        cmd = 'usage' unless script.respond_to? cmd
        script.send(cmd, *ARGV)
      end
    end
  end

  # Sinatra delegation mixin. Mixing this module into an object causes all
  # methods to be delegated to the Sinatra::Application class. Used primarily
  # at the top-level.
  module Delegator #:nodoc:
    def self.delegate(*methods)
      methods.each do |method_name|
        eval <<-RUBY, binding, '(__DELEGATE__)', 1
          def #{method_name}(*args, &b)
            ::Lacuna::Script.send(#{method_name.inspect}, *args, &b)
          end
          private #{method_name.inspect}
        RUBY
      end
    end

    delegate :start, :stop, :status, :restart, :usage, :cmd
  end

  at_exit { Script.run! if $!.nil? }
end

include Lacuna::Delegator