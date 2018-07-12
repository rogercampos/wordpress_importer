module WordpressImporter
  class Fixer
    include ActionView::Helpers::TextHelper

    def initialize(str, entry, doc, logger)
      @logger = logger
      @str = str
      @entry = entry
      @doc = doc
    end

    def result
      a = add_newline_after_titles(@str)
      a = convert_to_simple_format(a)
      a = remove_non_breaking_whitespaces(a)
      a = remove_captions(a)
      a = expand_galleries(a)
      a = remove_more(a)
      a = remove_empty_p(a)
      a = remove_newlines(a)
      a = fix_chars(a)
      a = fix_whitespace_after_comma_or_dot(a)
      a = remove_styles(a)
      a = wrap_img_in_p(a)
      a.gsub(/ {2,}/, " ")
    end

    def add_newline_after_titles(str)
      str.gsub("</h1>", "</h1>\n\n")
          .gsub("</h2>", "</h2>\n\n")
          .gsub("</h3>", "</h3>\n\n")
          .gsub("</h4>", "</h4>\n\n")
          .gsub("</h5>", "</h5>\n\n")
          .gsub("</h6>", "</h6>\n\n")
    end

    def remove_non_breaking_whitespaces(str)
      str.gsub("\u00A0", " ")
    end

    def wrap_img_in_p(str)
      doc = Nokogiri::HTML(str)
      doc.css('a>img').each do |node|
        a = doc.create_element "p"
        a.inner_html = node.parent.to_html
        node.parent.replace a.to_html
      end
      doc.css('img').each do |node|
        unless node.parent.name == "a"
          a = doc.create_element "p"
          a.inner_html = node.to_html
          node.replace a.to_html
        end
      end
      doc.to_html
    end

    def remove_styles(str)
      doc = Nokogiri::HTML(str)
      doc.xpath('//@style').remove
      doc.to_html
    end

    # This implementation replaces the [gallery] for <img> tags within a generic <gallery> tag, custom things should be done here to improve it.
    def expand_galleries(str)
      regexp = /\[gallery(.*?)\]/

      str.gsub(regexp) do |match|
        if match.include?("ids=")
          ids = /ids="(.*?)"/.match(match)[1].split(",")
          attachments = @doc.attachments.select { |x| ids.include?(x.id) }
        else
          attachments = @doc.attachments.select { |x| x.post_parent_id == @entry.id }
        end

        res = "<gallery>"
        attachments.each do |attachment|
          begin
            source = Saviour::UrlSource.new(attachment.attachment_url)
            a = Image.create! file: source, alt: attachment.title
            res << "<img src='#{a.file.url}' data-id='#{a.id}' alt='#{attachment.body}' />"
          rescue Exception
            @logger.error "Broken link #{source} on post = #{@entry.slug}"
          end
        end
        res << "</gallery>"
        res
      end
    end

    def fix_whitespace_after_comma_or_dot(str)
      str.gsub(/,(\w+?)/) { |x| ", #{x.split(',')[1]}" }
    end

    def fix_chars(str)
      str.gsub("’", "'")
    end

    def remove_newlines(str)
      str.gsub("\n", "").gsub("\t", "")
    end

    def remove_empty_p(str)
      str.sub("<p></p>", "")
    end

    def convert_to_simple_format(str)
      simple_format(str)
    end

    def remove_captions(str)
      regexp = /\[caption(.*?)\[\/caption\]/

      str.gsub(regexp) do |match|
        valid_xml = match.sub("[/caption]", "").gsub(/^.*\]/, '')

        doc = Nokogiri::XML(valid_xml).css("img")

        doc.remove_class

        doc[0].children = ""
        doc[0]["data-from-caption"] = "true"
        doc[0].to_s
      end
    end

    def remove_more(str)
      str.sub("<!--more-->", "")
    end
  end
end
