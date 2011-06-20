require 'pack/info'
require 'pack/fileutils'

include FileUtils

@@nano_pkg_dir = ENV['NANO_PACKAGE_DIR'] || '/usr/src/tools/tools/nanobsd/Pkg'
@@nano_arch = ENV['NANO_ARCH'] || `uname -p`.strip
mkdir_p @@nano_pkg_dir
@@indent = 0

LOADED={}
def loaded(info)
  info = FreePack::Info.new(info) unless info.is_a? FreePack::Info
  LOADED[info.name] = info
  info
end

installed = `pkg_info`.strip("\n")

Dir.glob("#{@@nano_pkg_dir}/*.tbz").each {|e| loaded(e) }

def source(src)
  @@src = src
end

def fetch_latest(name)
  puts "#{'-'*@@indent}Fetching latest #{name}"
  info = LOADED[name]
  unless info
    sh "fetch -o #{@@nano_pkg_dir} #{@@src}/Latest/#{name}.tbz"
    cd @@nano_pkg_dir do
      info=FreePack::Info.new("#{name}.tbz")
      mv "#{name}.tbz", "#{info.name}-#{info.version}.tbz"
      loaded info
    end
  end
  info
end

def fetch(name)
  unless File.exist?("#{@@nano_pkg_dir}/#{name}.tbz")
    puts "#{'-'*@@indent}Fetching #{name}"
    sh "fetch -o #{@@nano_pkg_dir} #{@@src}/All/#{name}.tbz" 
    loaded("#{@@nano_pkg_dir}/#{name}.tbz")
  else 
    puts "#{'-'*@@indent}Skipping fetch of #{name}"
  end
end

def pkg(name, version=nil)
  @@indent += 1
  info = if version
    fetch("#{name}-#{version}")
  else
    fetch_latest(name)
  end
  info.dependencies.each do |n, v|
    pkg(n, v)
  end
  @@indent -= 1
end

def port(name, options={})
  puts "#{'-'*@@indent}Building port #{name}"
  @@indent += 1
  location=`whereis -sq #{name}`.strip
  cd location do
    largs = options[:defines]
    largs = [options[:define]] unless largs || options[:define].nil?
    largs = [] unless largs
    if largs.is_a? Hash
      largs = largs.map{|key, value| "#{key}=#{value}"}
    end
    largs.map!{|d| d =~ /=/ ? d : "-D#{d}" }
    
    dependencies = `make run-depends-list #{largs.join(' ')}`.strip.split("\n")
    fullname = `make package-name #{largs.join(' ')}`.strip
    raise "Invalid package name" unless fullname =~ RegExp.new("^#{name}-(.*)$")
    version = $1
    unless File.exist?("#{@@nano_pkg_dir}/#{fullname}.tbz")
      dependencies.each do |e|
        port_pkg(e, :install=>true)
      end
      
      args="TARGET_ARCH=#{@@nano_arch} PKGFILE=#{@@nano_pkg_dir}/#{fullname}.tbz -DFORCE_PKG_REGISTER BATCH=yes #{largs}"
      sh "make clean #{args}"
      sh "make package #{args}"
    else
      dependencies.each do |e|
        port_pkg(e)
      end
    end
    loaded("#{@@nano_pkg_dir}/#{fullname}.tbz")
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