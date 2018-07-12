module WordpressImporter
  class ImageDownloader
    def initialize(url)
      @url = url
    end

    def file
      ext = File.extname(@url)
      a = Tempfile.new(["cuca", ext])
      a.binmode
      a.write open(@url).read
      a.flush
      a.fsync
      a.close

      if ext == ".png"
        b = MiniMagick::Image.open(a.path)
        b.format("jpg") do |c|
          c.background "white"
          c.interlace "Plane"
          c.quality "100"
          c.flatten
        end

        b
      else
        a
      end
    end
  end
end
