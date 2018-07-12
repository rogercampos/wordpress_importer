module WordpressImporter
  class PostsImporter
    def initialize(opts = {})
      @max = opts.fetch(:max, nil)
      @document = opts[:document] || raise("You must provide a parsed document")
      @logger = opts[:logger] || raise("You must provide a logger")
    end

    # Used to filter posts to import by slug
    def matching_slugs
      %w(
)
    end

    def import!
      post_entries.each do |entry|
        PostRunner.new(entry, @document, @logger).import!
      end

      draft_post_entries.each do |entry|
        DraftPostRunner.new(entry, @document, @logger).import!
      end
    end

    def draft_post_entries
      @document.entries.select { |x| x.type == "post" && x.status != "publish" }.shuffle
    end

    def post_entries
      total = @document.entries.select { |x| x.type == "post" && x.status == "publish" }

      total = total.sort_by {|x| x.published_at }.reverse

      if matching_slugs.any?
        total = total.select { |x| matching_slugs.include?(x.slug) }
      elsif @max
        total = total[0..@max]
      end

      total
    end
  end
end
