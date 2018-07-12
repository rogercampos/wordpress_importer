 module WordpressImporter
  class BackupDocument
    class Meta
      include SAXMachine

      element "wp:meta_key", as: :key
      element "wp:meta_value", as: :value
    end

    class Tag
      include SAXMachine

      element "wp:tag_slug", as: :slug
      element "wp:tag_name", as: :name
    end

    class Category
      include SAXMachine

      element "wp:category_nicename", as: :slug
      element "wp:category_parent", as: :parent
      element "wp:cat_name", as: :name
    end

    class Comment
      include SAXMachine

      element "wp:comment_id", as: :id
      element "wp:comment_author", as: :author_name
      element "wp:comment_author_email", as: :author_email
      element "wp:comment_author_url", as: :author_url
      element "wp:comment_date", as: :date
      element "wp:comment_content", as: :content
      element "wp:comment_type", as: :type
      element "wp:comment_parent", as: :parent_id
    end

    class Entry
      include SAXMachine

      element "title"
      element "dc:creator", as: :author
      element "content:encoded", as: :body
      element "description", as: :summary
      element "wp:post_date", as: :published_at
      element "wp:post_name", as: :slug
      element "wp:post_id", as: :id
      elements "category", with: {domain: "category"}, as: :categories
      elements "category", with: {domain: "post_tag"}, as: :tags
      elements "wp:comment", as: :comments, class: Comment
      elements "wp:postmeta", as: :metas, class: Meta

      element "wp:post_type", as: :type
      element "wp:status", as: :status
      element "wp:attachment_url", as: :attachment_url
      element "wp:post_parent", as: :post_parent_id

      def main_image_id
        a = self.metas.find { |x| x.key == "_thumbnail_id" }
        a.value if a
      end

      def longitude
        a = self.metas.find { |x| x.key == "geo_longitude" }
        a.value if a
      end

      def latitude
        a = self.metas.find { |x| x.key == "geo_latitude" }
        a.value if a
      end
    end


    include SAXMachine
    elements "item", as: :entries, class: Entry
    elements "wp:tag", as: :tags, class: Tag
    elements "wp:category", as: :categories, class: Category

    def attachments
      @attachments ||= entries.select { |x| x.type == "attachment" }
    end
  end
end
