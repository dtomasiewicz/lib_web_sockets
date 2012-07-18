Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'lib_web_sockets'
  s.version     = '0.0.0'
  s.summary     = 'HTML5 WebSockets implementation.'
  s.description = 'LibWebSockets is a not-quite-compliant server implementation of RFC 6455 built around Ruby\'s Socket library.'

  s.required_ruby_version = '>= 1.9.2'
  s.license = 'MIT'

  s.author   = 'Daniel Tomasiewicz'
  s.email    = 'dtomasiewicz@gmail.com'
  s.homepage = 'http://dtomasiewicz.com'

  s.files        = Dir['README.markdown', 'MIT-LICENSE', 'lib/**/*', 'examples/**/*']
  s.require_path = 'lib'
end