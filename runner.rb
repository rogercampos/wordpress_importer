require 'sax-machine'

module WordpressImporter
  class Runner
    def initialize(path, max = nil)
      @file = File.open(path)
      @max = max
    end

    def import!
      # run_tags!
      run_categories!
      run_posts!
      special_fixes_before! # only for tourismwithme blog

      apply_curumuchu!

      special_fixes_after!

      true
    end

    def special_fixes_before!
      Post.all.each do |post|
        SpecialFixerBefore.new(post).fix!
      end
    end

    def special_fixes_after!
      Post.all.each do |post|
        SpecialFixerAfter.new(post).fix!
      end
    end

    def apply_curumuchu!
      Content.delete_all

      Post.all.each do |post|
        a = Curumuchuer.new(post, logger)
        a.render!
        post.update_attributes content: a.result
      end
    end

    def run_tags!
      Tag.delete_all

      document.tags.each do |entry|
        Tag.create! slug: entry.slug, name: entry.name
      end
    end

    def run_categories!
      RootCategory.delete_all
      Category.delete_all

      registry = document.categories.map do |entry|
        {
            name: entry.name,
            slug: entry.slug,
            parent: entry.parent
        }
      end

      CategoryImporter.new(registry).import!
    end

    def run_posts!
      Post.delete_all
      Image.destroy_all
      Comment.delete_all

      PostsImporter.new(max: @max, document: document, logger: logger).import!
    end


    private

    def logger
      @logger ||= begin
        File.delete("wordpress_migration.log")
        Logger.new("wordpress_migration.log")
      end
    end

    def document
      @document ||= BackupDocument.parse(@file.read)
    end
  end
end
