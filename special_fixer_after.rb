module WordpressImporter
  class SpecialFixerAfter
    include ActionView::Helpers::SanitizeHelper

    def initialize(post)
      @post = post
    end

    def fix!
      remove_duplicated_main_image!
    end

    def remove_duplicated_main_image!
      return unless @post.main_image.url.present?

      main = ImageDownloader.new(@post.main_image.url).file

      @post.contents.select { |x| x.template_name == "image" }.each do |content|
        image = Image.find_by_id!(content.data["image_id"])
        target = ImageDownloader.new(image.file.url).file

        if ImageDiff.new(main.path, target.path).similar?
          new_str = @post.content.gsub("{% image: #{content.id} %}", "")

          @post.update_attributes content: new_str
          content.destroy!
        end
      end
    end
  end
end
