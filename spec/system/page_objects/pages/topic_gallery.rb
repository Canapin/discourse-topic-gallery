# frozen_string_literal: true

module PageObjects
  module Pages
    class TopicGallery < PageObjects::Pages::Base
      def visit_gallery(topic)
        page.visit("/t/#{topic.slug}/#{topic.id}/gallery")
        self
      end

      def has_topic_title?(text)
        has_css?(".topic-gallery-page h1", text: text)
      end

      def has_gallery_container?
        has_css?(".topic-gallery-page")
      end
    end
  end
end
