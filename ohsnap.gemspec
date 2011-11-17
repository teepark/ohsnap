
Gem::Specification.new do |spec|
  spec.name = "ohsnap"
  spec.version = "0.0.1"
  spec.date = Time.now.strftime("%Y-%m-%d")
  spec.summary = "ohsnap is a commandline photo management utility"
  spec.email = "travis.parker@gmail.com"
  spec.authors = ["Travis Parker"]

  spec.files = Dir.glob("lib/**/*")
  spec.files += Dir.glob("bin/**/*")

  spec.executables = ["ohsnap"]

  spec.add_dependency("sqlite3", ">= 1.3.4")
end
