class ImageDiff
  DEFAULT_TOLERANCE = 0.01

  def initialize(image_path_1, image_path_2, tolerance = DEFAULT_TOLERANCE)
    @image_path_1, @image_path_2 = image_path_1, image_path_2
    raise "File #{@image_path_1} does not exist" unless File.file?(@image_path_1)
    raise "File #{@image_path_2} does not exist" unless File.file?(@image_path_2)

    @resize_factor = 0.25
    @color_fuzz = 10
    @tolerance = tolerance
  end

  # Returns number between 0: completely different, and 1: exact match
  def similarity
    size1 = pixel_count(@image_path_1)
    size2 = pixel_count(@image_path_2)

    if size1 < size2
      big = @image_path_2
      small = @image_path_1
    else
      big = @image_path_1
      small = @image_path_2
    end

    min_size = size(small)
    width = min_size[0] * @resize_factor
    height = min_size[1] * @resize_factor

    a = "convert #{Shellwords.escape(small)} #{Shellwords.escape(big)} -resize '#{width}'x'#{height}'\! MIFF:- | compare -metric AE -fuzz \"#{@color_fuzz}%\" - null: 2>&1"
    result = `#{a}`

    result.to_i / (width * height)
  end

  def similar?(tolerance = @tolerance)
    similarity <= tolerance
  end

  def different?(tolerance = @tolerance)
    !similar?(tolerance)
  end

  private

  def size(path)
    `identify -format '%wx%h' #{Shellwords.escape(path)}`.strip.split("x").map(&:to_i)
  end

  def pixel_count(path)
    Float(`convert #{Shellwords.escape(path)} -format "%[fx:w*h]" info:`.strip)
  end
end
