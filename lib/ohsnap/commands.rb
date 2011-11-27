begin
  require 'sqlite3'
rescue LoadError
  require 'rubygems'
  require 'sqlite3'
end

require 'ohsnap/search'
require 'ohsnap/photos'

module OhSnap
  module Commands
    def self.init(args)
      if File.exist?("meta.db")
        STDERR.write("OhSnap! meta.db already exists!")
        exit 78
      end
      if File.exist?("original")
        STDERR.write("OhSnap! original directory already exists!")
        exit 78
      end
      if File.exist?("retouched")
        STDERR.write("OhSnap! retouched directory already exists!")
        exit 78
      end

      sql_file = "#{File.dirname(File.expand_path(__FILE__))}/init.sql"
      sql = File.open(sql_file) { |fp| fp.read }
      SQLite3::Database.open("meta.db") { |db| db.execute_batch(sql) }

      Dir.mkdir("original")
      Dir.mkdir("retouched")
    end

    def self.tags(args)
      SQLite3::Database.open("meta.db") do |db|
        db.execute("SELECT name FROM tag ORDER BY name") { |name| puts name }
      end
    end

    def self.search(args)
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
        puts OhSnap::Search.run(db, specs).inspect
      end
    end

    def self.import(args)
      #TODO: get exit codes right
      if args.empty?
        STDERR.write("OhSnap! missing a directory\n")
        exit(1)
      end
      unless File.directory?(args[0])
        STDERR.write("OhSnap! #{args[0]} isn't a directory\n")
        exit(1)
      end

      tags = []
      imported = 0
      Dir.glob("#{args[0]}/*").each do |path|
        if File.directory?(path)
          tags << path[args[0].size + 1..-1]
        else
          OhSnap::Photos.import(path)
          imported += 1
        end
      end

      tags.each do |tag|
        Dir.glob("#{args[0]}/#{tag}/*").each do |path|
          if File.file?(path)
            OhSnap::Photos.import(path)
            imported += 1
          end
        end
      end

      puts "imported #{imported} photos"
    end
  end
end
