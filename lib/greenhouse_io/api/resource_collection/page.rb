module GreenhouseIo
  class ResourceCollection
    class Page
      include Enumerable

      attr_reader :next_page_url, :contents

      def initialize(contents, next_page_url: nil, dehydrate_after_iteration: true)
        @next_page_url = next_page_url
        @contents = contents
        @dehydrate_after_iteration = dehydrate_after_iteration
      end

      def each
        return enum_for(:each) unless block_given?
        contents.map! do |item|
          yield item
          @dehydrate_after_iteration ? :dehydrated : item
        end
      end

      def method_missing(method_name, *arguments, &block)
        if contents.respond_to?(method_name, false)
          contents.send(method_name, *arguments, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        contents.respond_to?(method_name, include_private)
      end
    end
  end
end
