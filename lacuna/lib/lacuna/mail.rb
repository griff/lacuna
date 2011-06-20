require 'lacuna/fileutils'

module FileUtils
  def exim(*args)
    sh 'exim', *args
  end
end

module Lacuna
  
  def self.mails
    Programs.capture(:exim, '-bpu').split("\n\n").map{|q| MailQueueItem.new(q)}
  end
  def self.find_mail(id)
    mails.find{|m| m.id == id}
  end
  
  class MailQueueItem
    
    attr_reader :queue_time, :size, :id, :from, :to
    
    def initialize(items)
      @to = items.split("\n").map {|r| r.strip}
      line = @to.shift
      raise "Bad mail queue line '#{line}'" unless line =~ /^(\d+\w)\s+(\S+)\s+(\S+)\s+(.*)$/
      @queue_time, @size, @id, @from = $1, $2, $3, $4
      if @from =~ /\*\*\* frozen \*\*\*$/
        @frozen = true
        @from = @from[0..-16]
      end
    end
    
    def frozen?
      @frozen
    end
    
    def log
      IO.readlines(Lacuna.paths.exim_msglog/id)
    end
    
    def freeze
      Programs.exim "-Mf", id
    end
    
    def thaw
      Programs.exim "-Mt", id
    end
    
    def remove
      Programs.exim "-Mrm", id
    end
    
    def to_s
      r = recipients.map{|r|}
      "Mail{#{queue_time} #{size} #{id} #{from} #{frozen?} [#{recipients.join(', ')}]}"
    end
  end
end