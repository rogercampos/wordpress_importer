module WordpressImporter
  class DraftPostRunner < PostRunner
    def import!
      puts "[Wordpress Import - Draft] Running post #{@entry.slug}"

      post = Post.new
      post.save validate: false

      attrs = {
          title: @entry.title,
          content: parse_body,
          published_at: @entry.published_at && Time.zone.parse(@entry.published_at),
          slug: @entry.title.parameterize,
          longitude: longitude,
          latitude: latitude,
          workflow_state: "draft"
      }

      post.update_attributes!(attrs)
    end
  end
end
