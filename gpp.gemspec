lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "gpp/version"

Gem::Specification.new do |s|
  s.name        = "gpp"
  s.version     = GPP::VERSION
  s.date        = Time.now.strftime("%Y-%m-%d")
  s.summary     = "GPP"
  s.description = "A text pre-processor"
  s.authors     = ["Nathan Baum"]
  s.email       = "n@p12a.org.uk"
  s.executables = ["gpp"]
  s.files       = Dir["lib/**/*.rb"]
  s.homepage    = "http://www.github.org/nbaum/rpp"
  s.license     = "MIT"
end
