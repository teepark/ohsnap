module OhSnap
  class DiskPhoto
    DNG = 1 # file(1) shows image/tiff
    NEF = 2 # file(1) shows image/tiff
    CR2 = 3 # no idea yet what file(1) shows, but I have a guess
    PPM = 4
    TIF = 5
    PNG = 6
    JPG = 7

    def initialize(path)
      @path = path
    end

    def self.type_from_extension(ext)
      case ext.downcase
      when "dng"; DNG
      when "nef"; NEF
      when "cr2"; CR2
      when "ppm"; PPM
      when "pnm"; PPM
      when "pgm"; PPM
      when "pbm"; PPM
      when "pam"; PPM
      when "tif"; TIF
      when "tiff"; TIF
      when "png"; PNG
      when "jpg"; JPG
      when "jpeg"; JPG
      else; nil
      end
    end

    def filetype
      return @filetype if instance_variable_defined?(:@filetype)

      mimetype = `file -ib #{@path}`.sub(/;.*$/, "").chomp!
      if mimetype == "image/tiff"
        ext = @path.rpartition("/")[2].partition(".")[2]
        case ext.downcase
        when "dng"
          @filetype = DNG
        when "nef"
          @filetype = NEF
        else
          @filetype = TIF
        end
      elsif mimetype == "image/x-portable-pixmap"
        @filetype = PPM
      elsif mimetype == "image/jpeg"
        @filetype = JPG
      elsif mimetype == "image/png"
        @filetype = PNG
      else
        @filetype = nil
      end
      @filetype
    end

    def raw?
      [DNG, NEF, CR2].include?(filetype)
    end
  end
end
