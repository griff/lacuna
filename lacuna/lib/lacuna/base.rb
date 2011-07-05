module Lacuna
  class LacunaError < RuntimeError
  end

  class LacunaTaggedError < RuntimeError
    def initialize(msg=nil, options={})
      super(msg)
      @options = options
    end
    alias :tag :to_s

    attr_reader :options
    
    def http_status
      500
    end

    def translates
      [:"lacuna.errors.default.#{tag}", :"errors.default.#{tag}"]
    end

    def to_s
      opt = options.dup
      default = self.translates
      default << opt.delete(:default) if opt[:delete]
      opt = {:default=>default}.merge(opt) 
      I18n.t(default.shift, opt)
    end
  end
  
  class BadRequestError < LacunaTaggedError
    def translates
      [ 
        :"lacuna.errors.bad_request.#{tag}", 
        :"lacuna.errors.default.#{tag}", 
        :"errors.bad_request.#{tag}", 
        :"errors.default.#{tag}"
      ]
    end
    
    def http_status
      400
    end
  end
  
  class ConflictError < LacunaTaggedError
    def translates
      [ 
        :"lacuna.errors.conflict.#{tag}", 
        :"lacuna.errors.default.#{tag}", 
        :"errors.conflict.#{tag}", 
        :"errors.default.#{tag}"
      ]
    end

    def http_status
      409
    end
  end
  
  class ForbiddenError < LacunaTaggedError
    def translates
      [ 
        :"lacuna.errors.forbidden.#{tag}", 
        :"lacuna.errors.default.#{tag}", 
        :"errors.forbidden.#{tag}", 
        :"errors.default.#{tag}"
      ]
    end

    def http_status
      403
    end
  end
  
  def self.hostname
    @hostname ||= Programs.capture(:hostname).strip
  end

  def self.host
    @host ||= Programs.capture(:hostname, '-s').strip
  end
  
  def self.domain
    hostname[host.size+1..-1]
  end
end