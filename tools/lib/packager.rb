require 'pack/info'
require 'pack/fileutils'

include FileUtils

@@nano_pkg_dir = ENV['NANO_PACKAGE_DIR']
mkdir_p @@nano_pkg_dir

LOADED={}
def loaded(info)
  info = Pack::Info.new(info) unless info.is_a? Pack::Info
  LOADED[info.name] = info
  info
end

Dir.glob("#{@@nano_pkg_dir}/*.tbz").each {|e| loaded(e) }

def source(src)
  @@src = src
end

def fetch_latest(name)
  puts "Fetching latest #{name}"
  info = LOADED[name]
  unless info
    sh "fetch -o #{@@nano_pkg_dir} #{@@src}/Latest/#{name}.tbz"
    cd @@nano_pkg_dir do
      info=Pack::Info.new("#{name}.tbz")
      mv "#{name}.tbz", "#{info.name}-#{info.version}.tbz"
      loaded info
    end
  end
  info
end

def fetch(name)
  puts "Fetching #{name}"
  sh "fetch -o #{@@nano_pkg_dir} #{@@src}/All/#{name}.tbz" unless File.exist?("#{@@nano_pkg_dir}/#{name}.tbz")
  loaded("#{@@nano_pkg_dir}/#{name}.tbz")
end

def pkg(name, version=nil)
  info = if version
    fetch("#{name}-#{version}")
  else
    fetch_latest(name)
  end
  info.dependencies.each {|n, v| pkg(n, v)}
end

def port(name)
  puts "Building port #{name}"
  location=`whereis -sq #{name}`.strip
  cd location do
    `make run-depends-list`.strip.split("\n").each {|e| port_pkg(e)}
    name = `make package-name`.strip
    unless File.exist?("#{@@nano_pkg_dir}/#{name}.tbz")
      args="TARGET_ARCH=${NANO_ARCH} PKGFILE=#{@@nano_pkg_dir}/#{name}.tbz -DFORCE_PKG_REGISTER -DBATCH"
      sh "make clean #{args}"
      sh "make package #{args}"
    end
  end
end

def port_pkg(name)
  location=`whereis -sq #{name}`.strip
  cd location do
    name = `make package-name`.strip
  end
  info = fetch name
  info.dependencies.each {|n, v| pkg(n, v)}
end