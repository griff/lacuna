module FreePack
  class Info
    def self.split(name)
      if name =~ /(.+)-(\d+\..+)$/
        [$1, $2]
      else
        raise "Invalid name #{name}"
      end
    end
    
    attr_reader :name, :version, :dependencies, :file
    
    def initialize(file)
      @file = file
      text = `pkg_info -qf #{file}`
      raise "Invalid package" unless text =~ /@name\s(.+)/
      @name, @version = Info.split($1)
      @dependencies = text.split("\n").find_all {|e| e =~ /@pkgdep\s(.+)/}.map{|e| e =~ /@pkgdep\s(.+)/ ; Info.split($1)}
    end
    
    def fullname
      "#{name}-#{version}"
    end
    
    def install
      FileUtils.sh("pkg_add", file)
    end
    
    def uninstall(force=false)
      FileUtils.sh("pkg_delete", fullname)
    end
    
    def installed?
      FileUtils.sh('pkg_info', fullname) {|ok, status| ok}
    end
  end
end