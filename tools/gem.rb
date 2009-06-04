def dependency(gem, version='')
  version = "-v '#{version}'" if version && !version.empty?
  puts "gem install #{gem} ${NANO_GEM_OPTS} #{version}"
end

load ARGV[0]
