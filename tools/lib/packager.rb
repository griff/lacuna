require 'pathname'
require 'free_pack/info'
require 'free_pack/fileutils'

include FileUtils

@@pkg_dir = Pathname.new(ARGV[0] || ENV['LACUNA_TOOLS'] || '/usr/obj/lacuna/Pkg').realpath
@@target_arch = ARGV[1] || `uname -p`.strip
@@patch_dir = Pathname.new(ARGV[2] || ENV['LACUNA_TOOLS']).realpath
mkdir_p @@pkg_dir

@@indent = 0

LOADED={}
def loaded(info)
  info = FreePack::Info.new(info) unless info.is_a? FreePack::Info
  LOADED[info.name] = info
  info
end

installed = `pkg_info`.strip.split("\n")

Dir.glob("#{@@pkg_dir}/*.tbz").each {|e| loaded(e) }

def source(src)
  @@src = src
end

def fetch_latest(name)
  puts "#{'-'*@@indent}Fetching latest #{name}"
  info = LOADED[name]
  unless info
    sh "fetch -o #{@@pkg_dir} #{@@src}/Latest/#{name}.tbz"
    cd @@pkg_dir do
      info=FreePack::Info.new("#{name}.tbz")
      mv "#{name}.tbz", "#{info.name}-#{info.version}.tbz"
      loaded info
    end
  end
  info
end

def fetch(name)
  unless File.exist?("#{@@pkg_dir}/#{name}.tbz")
    puts "#{'-'*@@indent}Fetching #{name}"
    sh "fetch -o #{@@pkg_dir} #{@@src}/All/#{name}.tbz" 
  else 
    puts "#{'-'*@@indent}Skipping fetch of #{name}"
  end
  loaded("#{@@pkg_dir}/#{name}.tbz")
end

def pkg(name, *args)
  options = (Hash === args.last) ? args.pop : {}
  version = args.first
  @@indent += 1
  info = if version
    fetch("#{name}-#{version}")
  else
    fetch_latest(name)
  end
  info.dependencies.each do |n, v|
    pkg(n, v, options)
  end
  info.install if options[:install] && !info.installed?
  @@indent -= 1
end

def port(name, options={})
  @@indent += 1
  if name =~ %r{/}
    location = "/usr/ports/#{name}"
  else
    location=`whereis -sq #{name}`.strip
  end
  cd location do
    largs = options[:defines]
    largs = [options[:define]] unless largs || options[:define].nil?
    largs = [] unless largs
    if largs.is_a? Hash
      largs = largs.map{|key, value| "#{key}=#{value}"}
    end
    largs.map!{|d| d =~ /=/ ? d : "-D#{d}" }
    
    patches = options[:patches]
    patches = [options[:patch]] unless patches || options[:patch].nil?
    patches = [] unless patches
    
    patches.each do |patch|
      patch = File.join(@@patch_dir, patch)
      patch = patch + '.patch' unless File.exist?(patch)
      base = File.basename(patch)
      puts "#{'-'*@@indent}Applying patch #{base} to port #{name}"
      if File.exist?(".done.#{base}")
        sh 'find . -name \*.orig -and -not -path ./work/\* | sed "s/\.orig//" | xargs -I % mv %.orig %'
        FileUtils.rm(".done.#{base}")
      end
      sh 'patch', '-NEt','-p0', '-i', patch
      FileUtils.cp(patch, ".done.#{base}")
    end
    
    puts "#{'-'*@@indent}Building port #{name} with args #{largs.join(' ')}"
    
    dependencies = `make run-depends-list #{largs.join(' ')}`.strip.split("\n")
    fullname = `make package-name #{largs.join(' ')}`.strip
    raise "Invalid package name #{name} #{fullname}" unless fullname =~ Regexp.new("-([^-]*)$")
    version = $1
    unless File.exist?("#{@@pkg_dir}/#{fullname}.tbz")
      dependencies.each do |e|
        port_pkg(e, :install=>true)
      end
      args = largs + ["TARGET_ARCH=#{@@target_arch}", "PKGFILE=#{@@pkg_dir}/#{fullname}.tbz", "BATCH=yes"]
      args << "-DFORCE_PKG_REGISTER" if FreePack.installed?(fullname)
      
      sh "make", "clean", *args
      sh "make", "package", *args
    else
      dependencies.each do |e|
        port_pkg(e)
      end
    end
    loaded("#{@@pkg_dir}/#{fullname}.tbz")
  end
  @@indent -= 1
end

def port_pkg(name,options={})
  @@indent += 1
  location=`whereis -sq #{name}`.strip
  cd location do
    name = `make package-name`.strip
  end
  info = fetch name
  info.dependencies.each {|n, v| pkg(n, v, :install=>options[:install])}
  info.install if options[:install] && !info.installed?
  @@indent -= 1
end