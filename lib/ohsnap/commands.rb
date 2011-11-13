require 'optparse'
begin
  require 'sqlite3'
rescue LoadError
  require 'rubygems'
  require 'sqlite3'
end

begin
  require 'ohsnap'
  require 'ohsnap/search'
rescue LoadError
#TODO: knock out this conditional require once we're in business as a gem
  require 'search'
end

module OhSnap
  module Commands
    def self.init(args, opts)
      if File.exist?("meta.db")
        STDERR.write("OhSnap! meta.db already exists!")
        exit 78
      end
      if Dir.directory?("original")
        STDERR.write("OhSnap! original directory already exists!")
        exit 78
      end
      if Dir.directory?("retouched")
        STDERR.write("OhSnap! retouched directory already exists!")
        exit 78
      end

      sql_file = "#{File.dirname(File.expand_path(__FILE__))}/init.sql"
      sql = File.open(sql_file) { |fp| fp.read }
      SQLite3::Database.open("meta.db") { |db| db.execute_batch(sql) }

      Dir.mkdir("original")
      Dir.mkdir("retouched")
    end

    def self.tags(args, opts)
      SQLite3::Database.open("meta.db") do |db|
        db.execute("SELECT name FROM tag ORDER BY name") { |name| puts name }
      end
    end

    def self.search(args, opts)
      specs = []
      parser = OptionParser.new do |opts|
        opts.on("-t", "--tags", "=SEARCH_SPEC",
                "search for photos by their tags") do |spec|
          specs << [OhSnap::Search::TAG, spec]
        end

        opts.on("-r", "--retouched",
                "photos which have been retouched") do |spec|
          specs << [OhSnap::Search::ORIGINAL, "&0"]
        end

        opts.on("-o", "--original",
                "photos for which we still have the original") do |spec|
          specs << [OhSnap::Search::ORIGINAL, "&1"]
        end

        opts.on("-e", "--extension", "=SEARCH_SPEC",
                "search for photos by their filetype") do |spec|
          specs << [OhSnap::Search::TYPE, spec]
        end
      end

      parser.parse(args)

      SQLite3::Database.open("meta.db") do |db|
        OhSnap::Search.run(db, specs)
      end
    end
  end
end