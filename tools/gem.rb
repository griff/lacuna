def dependency(gem, version='')
  version = "-v '#{version}'" if version && !version.empty?
  gem_opts = ENV['NANO_GEM_OPTS']
  print "#{gem} #{gem_opts} #{version}^"
end

load ARGV[0]