module Pack
  class Info
    def self.split(name)
      if name =~ /(.+)-(\d+\..+)$/
        [$1, $2]
      else
        raise "Invalid name #{name}"
      end
    end
    
    attr_reader :name, :version, :dependencies
    
    def initialize(file)
      text = `pkg_info -qf #{file}`
      if text =~ /@name\s(.+)/
        @name, @version = Info.split($1)
      else
        raise "Invalid package"
      end
      @dependencies = text.split("\n").find_all {|e| e =~ /@pkgdep\s(.+)/}.map{|e| e =~ /@pkgdep\s(.+)/ ; Info.split($1)}
    end
  end
end