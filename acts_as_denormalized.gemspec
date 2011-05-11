# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "acts_as_denormalized/version"

Gem::Specification.new do |s|

  s.name        = "acts_as_denormalized"
  s.version     = ActsAsDenormalized::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Robert Head"]
  s.email       = ["robert.head@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Specify this act if you want to automatically calculate denormalized values on save.}
  s.description = <<desc
Specify this act if you want to automatically calculate denormalized values on save.\
Dependency: Ruby on Rails 2.1 or higher.

Denormalizing data is a common strategy to help reduce database reads (especially joins).
See: http://en.wikipedia.org/wiki/Denormalization

For example, in a forum, if I want to display the name of the author of each post,
I could store the author's name in the Post objects instead of fetching all the associated User records.
Storing the author's name in the Post is redundant (not normalized), but avoids loading the user record
just to read the name.

Tradeoff:
At the cost of slower writes and some potential for stale data,
you get faster reads by avoiding loading models you would otherwise have needed.
desc

  s.files         = %w(lib/acts_as_denormalized.rb)
  
  s.test_files    = Dir.glob("test/**/*")
  s.test_files    += 'Gemfile Rakefile'
  
  s.require_paths = ["lib"]

  s.add_dependency "activerecord", "~>2.3"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rails", "~>2.3"

end
