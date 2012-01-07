module OhSnap
  module Search
    TAG = 1
    ORIGINAL = 2
    TYPE = 3
    EXIF = 4

    def self.run(db, specs)
      return [] if specs.empty?

      stmt = "SELECT id FROM photo WHERE 1=#{specs[0][1][0,1] == "+" ? 0 : 1}"
      params = []
      specs.each do |pair|
        selector, spec = pair
        sql, args = spec_to_selects(selector, spec)
        stmt += sql
        params += args
      end

      stmt = db.prepare(stmt)
      result = stmt.execute(*params).to_a
      stmt.close
      result
    end

    def self.spec_to_selects(selector, spec)
      spec.scan(/.+?(?=[-+]|$)/).reduce(["", []]) do |memo, piece|
        op = case piece[0,1]
             when "+"
               "UNION"
             when "-"
               "EXCEPT"
             when "&"
               "INTERSECT"
             end
        piece = piece[1..-1]
        select = case selector
                 when TAG
                   tag_select(piece)
                 when ORIGINAL
                   original_select(piece)
                 when TYPE
                   type_select(piece)
                 when EXIF
                   exif_select(piece)
                 end
        args = select[1..-1]
        select = select[0]
        [memo[0] + " #{op} #{select}", memo[1] + args]
      end
    end

    def self.tag_select(piece)
      ["SELECT photo_tag.photo FROM tag INNER JOIN photo_tag" +
       " ON tag.id = photo_tag.tag WHERE tag.name = ?", piece]
    end

    def self.original_select(piece)
      ["SELECT DISTINCT photo FROM photo_representation WHERE original = ?",
       (eval piece)]
    end

    def self.type_select(piece)
      ["SELECT DISTINCT photo FROM photo_representation WHERE type = ?",
        DiskPhoto.type_from_extension(piece)]
    end

    def self.exif_select(piece)
      ["SELECT DISTINCT photo FROM exif_info WHERE key = ? AND value = ?", piece]
    end
  end
end
