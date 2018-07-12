module WordpressImporter
  class SpecialFixerBefore
    def initialize(post)
      @post = post
    end

    def fix!
      remove_h1!
    end

    def remove_h1!
      str = @post.content

      doc = Nokogiri::HTML(str)
      doc.css('h1').each do |node|
        node.replace ""
      end

      @post.update_attributes! content: doc.to_html
    end
  end
end
