require 'dragonfly'

module Middleman
  module DragonflyThumbnailer
    class Extension < Middleman::Extension
      attr_accessor :images

      def initialize(app, options_hash = {}, &block)
        super
        @images = []
        configure_dragonfly
      end

      def absolute_source_path(path)
        File.join(app.config[:source], app.config[:images_dir], path)
      end

      def build_path(image)
        dir = File.dirname(image.meta['original_path'])
        subdir = image.meta['geometry'].gsub(/[^a-zA-Z0-9\-]/, '')
        File.join(dir, subdir, image.name)
      end

      def absolute_build_path(image)
        File.join(app.config[:build_dir], app.config[:images_dir],
                  build_path(image))
      end

      def thumb(path, geometry)
        # First try using the given path.
        absolute_path = File.join(app.config[:source], path)
        unless File.exists?(absolute_path)
          # Then try using the other path
          absolute_path = absolute_source_path path
        end
        raise "Could not find image with path '#{absolute_path}'" unless File.exist?(absolute_path)

        image = ::Dragonfly.app.fetch_file(absolute_path)
        image.meta['original_path'] = path
        image.meta['geometry'] = geometry
        image = image.thumb(geometry)
        images << image
        image
      end

      def in_image_folder(path)
        absolute_path = File.join(app.config[:source], path)
        return File.exists?(absolute_path)
      end

      def after_build(builder)
        images.each do |image|
          builder.say_status :create, build_path(image)
          path = absolute_build_path(image)
          image.to_file(path).close
        end
      end

      helpers do
        def thumb_tag(path, geometry, options = {})
          image = extensions[:dragonfly_thumbnailer].thumb(path, geometry)
          return unless image

          if environment == :development
            url = image.b64_data
          else
            url = extensions[:dragonfly_thumbnailer].build_path(image)
            unless extensions[:dragonfly_thumbnailer].in_image_folder(path) then
              #HACK: Strip leading slash
              url = url[1..-1] if url[0] == "/"
            end
          end

          image_tag(url, options)
        end
      end

      private

      def configure_dragonfly
        ::Dragonfly.app.configure do
          datastore :memory
          plugin :imagemagick
        end
      end
    end
  end
end

::Middleman::Extensions.register(
  :dragonfly_thumbnailer,
  Middleman::DragonflyThumbnailer::Extension
)
