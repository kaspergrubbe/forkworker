require "fileutils"

# INSTALL DEPENDENCIES
# --------------------------------------------------------------------------------
require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "pry"
  gem "pry-remote"
  gem "redis"

  gem "image_optim"
  gem "image_optim_pack"

  gem "ruby-vips"

  gem "image_size"

  gem "ruby-filemagic"

  gem "forkworker", path: "."
end

# HELPERS
# --------------------------------------------------------------------------------
def new_redis_client
  Redis.new(
    url: "redis://127.0.0.1:6379/15",
    reconnect_attempts: 10,
    reconnect_delay: 1.5,
    reconnect_delay_max: 10.0,
  )
end

def duration
  start_time = Time.now.utc.to_f
  block = if block_given?
    yield
  end
  end_time = Time.now.utc.to_f
  duration = end_time - start_time

  return [block, duration]
end

class Image
  attr_reader :path, :file_size, :width, :height, :mime_type

  def initialize(path)
    @path = path
    @file_size = File.open(path).size / 1024
    @width, @height = ImageSize.path(path).size
    @mime_type = FileMagic.new(FileMagic::MAGIC_MIME).file(path).split(";").first
  end

  def thumbnail(width)
    new_path = add_effect_to_path(self.path, "-scaled-#{width}").gsub("testimages", "tempimages")

    image = Vips::Image.new_from_file(self.path)
    image = image.thumbnail_image(width, height: 10000000)
    image.write_to_file(new_path)

    Image.new(new_path)
  end

  def optimize
    image_optim = ImageOptim.new
    new_path = add_effect_to_path(self.path, "-optimize").gsub("testimages", "tempimages")

    File.open(new_path, "w") do |file|
      file.write(image_optim.optimize_image(self.path).read)
      file.close
    end

    Image.new(new_path)
  end

  private

  def add_effect_to_path(path, effect)
    if path.include?(".")
      filename, _, extension = path.rpartition(".")
      [filename, effect, '.', extension].join
    else
      [path, effect].join
    end
  end
end

# SETUP
# --------------------------------------------------------------------------------
FileUtils.mkdir_p("tests/redis/tempimages")

puts "Importing imagepaths into Redis"
_redis = new_redis_client
_redis.del("imagepaths")
Dir["tests/redis/testimages/*.*"].each do |imagepath|
  _redis.sadd("imagepaths", imagepath)
end
puts "... done!"
_redis.disconnect!
_redis = nil

# SETUP BLOCKS
# --------------------------------------------------------------------------------
progress = Proc.new {
  _redis = new_redis_client
  items_left = _redis.scard("imagepaths")
  puts "-- Processing left: #{items_left}"
  _redis.disconnect!
}

prefork = Proc.new {
  _redis = new_redis_client

  begin
    items_left = _redis.scard("imagepaths")
    if items_left == 0
      raise Forkworker::NoMoreWork.new
    end
  ensure
    _redis.disconnect!
  end
}

work = Proc.new {
  _redis = new_redis_client
  image_paths = _redis.spop("imagepaths", 2)
  update_title "Processing 0/#{image_paths.size}"

  image_paths.each.with_index(1) do |image_path, index|
    begin
      update_title "Processing #{index}/#{image_paths.size}"

      i = Image.new(image_path)

      t, t_elapsed = duration do
        i.thumbnail(100)
      end

      o, o_elapsed = duration do
        i.optimize
      end
    rescue StandardError => e
      puts [image_path, e.class.to_s, e.message].join(" - ")
    ensure
      puts [i.path, i.file_size, i.mime_type, i.width, i.height, t&.file_size, t_elapsed, o&.file_size, o_elapsed].join(" - ")
    end
  end

  _redis.disconnect!
  sleep 0.5
}

# RUN THE JOB
# --------------------------------------------------------------------------------
fw = Forkworker::Leader.new(1,
  prefork_block: prefork,
  fork_block: work,
  reporting_block: progress,
)
fw.start!

# TEST
# --------------------------------------------------------------------------------
original_images = Dir["tests/redis/testimages/*.*"]

optimized_images = Dir["tests/redis/tempimages/*-optimize.*"]
if original_images.size != optimized_images.size
  raise "There's only #{optimized_images.size} optimized images, but #{original_images.size} original images"
end

scaled_images = Dir["tests/redis/tempimages/*-scaled-100.*"]
if original_images.size != scaled_images.size
  raise "There's only #{scaled_images.size} optimized images, but #{original_images.size} original images"
end

puts
puts "All tests passed!"

# CLEANUP
# --------------------------------------------------------------------------------
if File.directory?("tests/redis/tempimages")
  FileUtils.remove_dir("tests/redis/tempimages")
end
