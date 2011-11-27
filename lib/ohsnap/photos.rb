module OhSnap
  module Photos
    def self.import(path)
      SQLite3::Database.open("meta.db") do |db|
        stmt = db.prepare("INSERT INTO photo (date, hash) values (?, ?);")
      end
    end
  end
end
