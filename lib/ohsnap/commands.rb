require 'rubygems'
require 'sqlite3'

require 'search'

module OhSnap
  module Commands
    def init(args, opts)
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

    def tags(args, opts)
      SQLite3::Database.new("meta.db") do |db|
        db.execute("SELECT name FROM tag ORDER BY name") { |name| puts name }
      end.close
    end

    def search(args, opts)
      
    end
  end
end
