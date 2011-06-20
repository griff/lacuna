Dir["#{File.dirname(__FILE__)}/app/*.rb"].sort.map do |path|
  path = File.basename(path, '.rb')
  require "lacuna/app/#{path}"
end
