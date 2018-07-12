module WordpressImporter
  class CategoryImporter
    def initialize(entries)
      @entries = entries
    end

    def import!
      # Create parent levels
      @entries.select { |x| x[:parent].present? }.each do |entry|
        existing = RootCategory.find_by(slug: entry[:parent])

        unless existing
          cat = @entries.find { |x| x[:slug] == entry[:parent] }
          RootCategory.create! name: cat[:name], slug: cat[:slug]
        end
      end

      # Create sublevels
      @entries.each do |entry|
        next if RootCategory.find_by(slug: entry[:slug]) # Dont create existing top levels

        opts = {
            name: entry[:name],
            slug: entry[:slug]
        }

        if entry[:parent]
          opts[:root_category_id] = RootCategory.find_by(slug: entry[:parent]).id
        end

        Category.create! opts
      end
    end
  end
end
