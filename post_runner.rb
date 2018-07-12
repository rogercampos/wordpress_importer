module WordpressImporter
  class PostRunner
    def initialize(entry, doc, logger)
      @entry = entry
      @doc = doc
      @images = []
      @logger = logger
    end

    def import!
      return if Post.find_by(slug: @entry.slug)
      puts "[Wordpress Import - Published] Running post #{@entry.slug}"

      post = Post.new
      post.save validate: false

      published_at = @entry.published_at && Time.zone.parse(@entry.published_at)

      attrs = {
          title: @entry.title,
          content: parse_body,
          published_at: published_at,
          created_at: published_at || Time.now,
          slug: @entry.slug,
          main_image: main_image,
          header_image: main_image,
          longitude: longitude,
          latitude: latitude,
          workflow_state: "published"
      }

      post.assign_attributes(attrs)
      post.save validate: false

      # @entry.tags.each do |tag|
      #   tag = Tag.find_by!(name: tag)
      #   Tagging.create! post: post, tag: tag
      # end

      if @entry.categories && @entry.categories.any?
        @entry.categories.map { |x| Category.find_by(name: x) }.compact.each do |category|
          PostCategory.create! post: post, category: category
        end
      end

      run_comments(post, @entry)
    end

    def create_comment(post, post_entry, comment_entry)
      if comment_entry.parent_id.present? && comment_entry.parent_id != "0"
        parent_comment_entry = post_entry.comments.find { |x| x.id == comment_entry.parent_id }
        raise("Cannot found comment #{comment_entry.parent_id} on post #{post.slug}") unless parent_comment_entry
        parent = create_comment(post, post_entry, parent_comment_entry)
      end

      attrs = {
          created_at: Time.zone.parse(comment_entry.date),
          author_name: comment_entry.author_name,
          author_url: comment_entry.author_url,
          author_email: comment_entry.author_email,
          content: comment_entry.content
      }

      # Other runs may have already created this comment, equality checked just by content and author
      existing_same_comment = post.comments(true).where(author_name: attrs[:author_name]).where(content: attrs[:content]).first

      if existing_same_comment
        existing_same_comment
      else
        attrs[:parent_id] = parent.id if parent
        Comment.create! attrs.merge(post_id: post.id, approved: true)
      end
    end

    def run_comments(post, entry)
      valid_comment_entries = entry.comments.select { |x| x.type.blank? }

      valid_comment_entries.each do |comment_entry|
        create_comment(post, entry, comment_entry)
      end
    end

    def longitude
      @entry.longitude.presence.try(:to_f)
    end

    def latitude
      @entry.latitude.presence.try(:to_f)
    end

    def main_image
      if @entry.main_image_id && (found = @doc.attachments.find { |x| x.id == @entry.main_image_id })
        image_source_from_url found.attachment_url
      elsif @images.any?
        image_source_from_url @images.first.file.url
      elsif img_found = @doc.attachments.find { |x| x.post_parent_id == @entry.id }
        image_source_from_url img_found.attachment_url
      else
        @logger.error "MISSING IMAGE: post: #{@entry.slug}"
        Saviour::UrlSource.new("http://joesvirtualbar.com/wp-content/uploads/2012/08/Il-successo-di-Example-comp.jpg")
      end
    rescue ArgumentError
      @logger.error "MISSING IMAGE: post: #{@entry.slug}"
      Saviour::UrlSource.new("http://joesvirtualbar.com/wp-content/uploads/2012/08/Il-successo-di-Example-comp.jpg")
    end

    def parse_body
      html = @entry.body.force_encoding("utf-8")
      doc = Nokogiri::HTML.fragment(html)

      doc.css("img").each do |img|
        begin
          image = Image.create!(file: image_source(img[:src]), alt: img[:alt])
          @images.push image
          img[:src] = image.file.url
          img["data-id"] = image.id
        rescue Exception
          # pass, leave broken links for now.
          @logger.error "Broken link #{img[:src]} on post = #{@entry.slug}"
        end
      end

      body = doc.to_html
      body = Fixer.new(body, @entry, @doc, @logger).result
      body
    end

    def image_source(data)
      if data.start_with?("data:image/")
        binary = Base64.decode64(data[22..-1])
        image_source_from_raw(binary, "#{SecureRandom.hex}.png")
      elsif data =~ /^(http|https)/
        image_source_from_url(data)
      else
        raise "Cannot handle this kind of image #{data}"
      end
    end

    def image_source_from_url(url)
      begin
        open(url)

        ext = File.extname(url)
        if ['.jpg', '.jpeg'].include?(ext)
          Saviour::UrlSource.new(url)
        elsif ext == ".png"
          convert_to_jpeg_raw(open(url).read, File.basename(url, ".*"))
        else
          raise "Not supported extension! [#{ext}] on url #{url}"
        end

      rescue OpenURI::HTTPError
        @logger.error "MISSING IMAGE: post: #{@entry.slug}"
        Saviour::UrlSource.new("http://joesvirtualbar.com/wp-content/uploads/2012/08/Il-successo-di-Example-comp.jpg")
      end
    end

    def image_source_from_raw(raw, filename)
      ext = File.extname(filename)

      if ext == ".png"
        convert_to_jpeg_raw(raw, filename)
      else
        Saviour::StringSource.new(raw, filename)
      end
    end

    def convert_to_jpeg_raw(png_raw, name)
      Tempfile.open(["blabla", ".png"]) do |f|
        f.binmode
        f.write(png_raw)

        a = MiniMagick::Image.open(f.path)
        a.format("jpg") do |c|
          c.background "white"
          c.interlace "Plane"
          c.quality "100"
          c.flatten
        end

        raw = File.read(a.path)

        File.delete(a.path)
        f.delete

        new_filename = "#{name}.jpg"
        Saviour::StringSource.new(raw, new_filename)
      end
    end
  end
end
