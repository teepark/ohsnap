require 'digest/sha1'
require 'fileutils'
require 'time'

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
    class << self
      private

      def get_extension(path)
        path.rpartition("/")[2].rpartition(".")[2].downcase
      end

      def get_exif(path)
        `exiftool -s #{path}`.lines.map do |line|
          key, _, value = line.partition(":")
          [key.strip!, value.strip!]
        end
      end

      def cp_to_path(base, src, hash, index=nil)
        dir = "#{base}/#{hash[0..1]}"
        begin
          Dir.mkdir(dir)
        rescue
        end
        suffix = index ? "-#{index}" : ""
        ext = src.rpartition(".")[2].downcase
        FileUtils.cp(src, "#{dir}/#{hash[2..-1]}#{suffix}.#{ext}")
      end
    end

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

        opts.on("-x", "--exif", "=EXIF_KVSPEC",
                "search for photos by exif data key/values") do |spec|
          specs << [OhSnap::Search::EXIF, spec]
        end
      end
      parser.parse(args)

      # validate the specs
      specs.each do |type, spec|
        unless %w(+ - &).include?(spec[0])
          STDERR.write("OhSnap! \"#{spec}\" is an invalid spec\n")
          exit(1)
        end
      end

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

      path_info = [] # [path, path-without-extension, tag-list]
      tags = []
      Dir.glob("#{args[0]}/*").each do |path|
        if File.directory?(path)
          tags << path[args[0].size + 1..-1]
        else
          path_info << [path, path.sub(/\.[^.]*$/, ""), []]
        end
      end

      tags.each do |tag|
        Dir.glob("#{args[0]}/#{tag}/*").each do |path|
          if File.file?(path)
            path_info << [path, path.sub(/\.[^.]*$/, ""), [tag]]
          end
        end
      end

      to_import = {}
      path_info.each do |path, without_ext, taglist|
        if to_import.include?(without_ext)
          paths, alltags = to_import[without_ext]
          paths << path
          taglist.each { |tag| alltags << tag unless alltags.include?(tag) }
        else
          to_import[without_ext] = [[path], taglist]
        end
      end

      # check for multiple raw files for a single photo
      to_import.each_value do |paths, tags|
        raws = paths.select do |p|
          %w(dng nef cr2).include?(get_extension(p))
        end
        if raws.size > 1
          STDERR.write("OhSnap! multiple raws for one image: #{raws.inspect}\n")
          exit(1)
        end
      end

      to_import = to_import.each_value.map do |paths, tags|
        priorities = %w(nef cr2 dng tif tiff png jpg jpeg)
        options = paths.sort_by { |p| priorities.index(get_extension(p)) or 100 }
        { :original => options[0],
          :retouched => options[1..-1],
          :tags => tags,
          :hash => Digest::SHA1.new.update(open(options[0]).read).hexdigest
        }
      end

      db = SQLite3::Database.new("meta.db")
      db.transaction do
        photo_ins = db.prepare(<<-EOSQL)
INSERT INTO photo (date, hash) VALUES (?, ?);
EOSQL
        photo_sel = db.prepare(<<-EOSQL)
SELECT id FROM photo WHERE hash = ? AND date = ?;
EOSQL
        repr_ins = db.prepare(<<-EOSQL)
INSERT INTO photo_representation
  (photo, original, type, height, width)
VALUES
  (?, ?, ?, ?, ?);
EOSQL
        exif_ins = db.prepare(<<-EOSQL)
INSERT INTO exif_info
  (photo, key, value)
VALUES
  (?, ?, ?);
EOSQL
        tag_sel = db.prepare(<<-EOSQL)
SELECT id from tag where name = ?;
EOSQL
        tag_ins = db.prepare(<<-EOSQL)
INSERT INTO tag (name) VALUES (?);
EOSQL
        phototag_ins = db.prepare(<<-EOSQL)
INSERT INTO photo_tag (photo, tag) VALUES (?, ?);
EOSQL

        to_import.each do |photo|
          type = DiskPhoto.new(photo[:original]).filetype
          next unless type

          exif = get_exif(photo[:original])
          exifhash = {}
          exif.each { |k, v| exifhash[k] = v }
          date = exifhash["DateTimeOriginal"]
          if date
            date = DateTime.strptime(date, "%Y:%m:%d %T")
          else
            date = open(photo[:original]).ctime.to_datetime
          end
          date = date.strftime("%Y-%m-%d %T")

          # insert the photo and get its id
          photo_ins.execute(date, photo[:hash])
          photo_id = photo_sel.execute(photo[:hash], date).first[0]

          # insert the photo_representation for the original
          repr_ins.execute(photo_id, 1, type,
                           exifhash["ImageHeight"].to_i,
                           exifhash["ImageWidth"].to_i)

          # insert all the exif data
          exif.each do |key, value|
            exif_ins.execute(photo_id, key, value)
          end

          # insert the photo_representations for the retouches
          photo[:retouched].each do |path|
            type = DiskPhoto.new(path).filetype
            exif = get_exif(path)
            exifhash = {}
            exif.each { |k, v| exifhash[k] = v }
            repr_ins.execute(photo_id, 0, type,
                             exifhash["ImageHeight"].to_i,
                             exifhash["ImageWidth"].to_i)
          end

          # connect each of the tags to the photo
          photo[:tags].each do |tag|
            # getset the tag -- to handle the race just try inserting first
            begin
              tag_ins.execute(tag)
            rescue
            end
            tag_id = tag_sel.execute(tag).first[0]

            # insert the join row
            phototag_ins.execute(photo_id, tag_id)
          end
        end

        photo_ins.close
        photo_sel.close
        repr_ins.close
        exif_ins.close
        tag_sel.close
        tag_ins.close
        phototag_ins.close
      end

      # copy image files to the proper new locations
      to_import.each do |photo|
        cp_to_path("original", photo[:original], photo[:hash])

        photo[:retouched].each_with_index do |path, index|
          cp_to_path("retouched", path, photo[:hash], index + 1)
        end
      end
    end
  end
end
