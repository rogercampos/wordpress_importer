require 'open-uri'

module WordpressImporter
  class Curumuchuer
    def initialize(post, logger)
      @post = post
      @logger = logger
    end

    def result
      doc.to_html
    end

    def doc
      @doc ||= Nokogiri::HTML.fragment(@post.content)
    end

    def render!
      puts "[Curumuchuer] Running Post #{@post.slug}"

      # CAUTION, Order is important
      parse_gallery!
      parse_zoomable_images!
      parse_images_with_links!
      parse_images!
      parse_links_to_posts!
      parse_links!
      parse_youtube!
      parse_vimeo!
    end

    def parse_zoomable_images!
      doc.css("a img").each do |match|
        return if !match["data-id"]

        ext = File.extname(match.parent[:href])

        unless [".jpg", ".jpeg", ".png"].include?(ext)
          next # Not linking to an image
        end

        image_1 = download_file(match["src"])
        image_2 = download_file(match.parent[:href])

        if !File.file?(image_1.path) || !File.file?(image_2.path)
          @logger.error "[curumuchu] in post #{@post.slug} image does not exist! cannot parse zoomable image"
          next
        end

        diff = ImageDiff.new(image_1.path, image_2.path)
        next unless diff.similar? # If both are the same image it's a zoomable image, if not is just an image with a link.

        image = Image.find_by_id!(match["data-id"])
        image.update_attributes! file: File.open(image_2.path)

        show_caption = match["data-from-caption"].present?

        foo = Content.new(post: @post, template_name: "image", data: {image_id: image.id, zoomable: true, show_caption: show_caption})
        foo.save validate: false
        match.parent.replace "{% image: #{foo.id} %}"
      end
    end

    def parse_gallery!
      doc.css("gallery").each do |match|
        image_ids = match.css("img").map do |img|
          img["data-id"]
        end.compact
        foo = Content.new post: @post, template_name: "gallery", data: {image_ids: image_ids}
        foo.save validate: false
        match.replace "{% gallery: #{foo.id} %}"
      end
    end

    def parse_images_with_links!
      doc.css("a img").each do |match|
        if match["data-id"]
          href = match.parent[:href]
          image = Image.find_by_id!(match["data-id"])

          foo = Content.new post: @post, template_name: "link_with_image", data: {image_id: image.id, url: href}
          foo.save validate: false
          match.parent.replace "{% link_with_image: #{foo.id} %}"
        else
          match.parent.replace ""
        end
      end
    end

    def parse_links_to_posts!
      doc.css("a").each do |link|
        next unless link[:href] =~ /tourismwithme\.com/
        uri = URI(link[:href])
        slug = uri.path[1..-1]
        anchor = link.text.strip

        post = Post.find_by_slug slug

        if post
          foo = Content.new post: @post, template_name: "link_to_post", data: {post_id: post.id, anchor: anchor}
          foo.save validate: false

          link.replace "{% link_to_post: #{foo.id} %}"
        end
      end
    end

    def parse_links!
      doc.css("a").each do |link|
        anchor = link.text.strip
        dest = link[:href].strip

        foo = Content.new post: @post, template_name: "link", data: {url: dest, anchor: anchor}
        foo.save validate: false

        link.replace "{% link: #{foo.id} %}"
      end
    end

    def parse_images!
      doc.css("img").each do |img|
        if img["data-id"]
          image = Image.find_by_id!(img["data-id"])
          show_caption = img["data-from-caption"].present?

          foo = Content.new post: @post, template_name: "image", data: {image_id: image.id, show_caption: show_caption}
          foo.save validate: false
          img.replace "{% image: #{foo.id} %}"
        else
          img.replace ""
        end
      end
    end

    def parse_youtube!
      # First look for iframe integrations
      doc.css("iframe").each do |iframe|
        next unless iframe[:src] =~ /youtube\.com/

        code = URI(iframe[:src]).path.split("/").last
        foo = Content.new post: @post, template_name: "youtube", data: {code: code.strip}
        foo.save validate: false

        iframe.replace "{% youtube: #{foo.id} %}"
      end

      # Now look for raw integrations, as a youtube link in cleartext
      regexp = /[>\s]+(https?:\/\/www\.youtube\.com\/watch.*?)[<\s]+/
      raw = doc.to_html

      a = regexp.match(raw).try(:captures) || []

      a.each do |link|
        uri = URI(link)

        raise "Cannot be!" if uri.query.blank?
        code = CGI.parse(uri.query)["v"].last
        foo = Content.new post: @post, template_name: "youtube", data: {code: code.strip}
        foo.save validate: false

        raw.gsub!(link, "{% youtube: #{foo.id} %}")
      end

      @doc = Nokogiri::HTML.fragment(raw)
    end

    def parse_vimeo!
      # First look for iframe integrations
      doc.css("iframe").each do |iframe|
        next unless iframe[:src] =~ /vimeo\.com/

        code = iframe[:src].strip.split("/").last
        foo = Content.new post: @post, template_name: "vimeo", data: {code: code.strip}
        foo.save validate: false

        iframe.replace "{% vimeo: #{foo.id} %}"
      end


      # Now look for raw integrations, as a youtube link in cleartext
      regexp = /[>\s]+(https?:\/\/vimeo\.com\/.*?)[<\s]+/
      raw = doc.to_html

      a = regexp.match(raw).try(:captures) || []

      a.each do |link|
        uri = URI(link)
        code = uri.path.split("/").last.strip
        foo = Content.new post: @post, template_name: "vimeo", data: {code: code.strip}
        foo.save validate: false

        raw.gsub!(link, "{% vimeo: #{foo.id} %}")
      end

      @doc = Nokogiri::HTML.fragment(raw)
    end

    private

    def download_file(url)
      ImageDownloader.new(url).file
    end
  end
end
