# frozen_string_literal: true

# name: discourse-topic-gallery
# about: TODO
# meta_topic_id: TODO
# version: 0.0.1
# authors: Canapin & AI
# url: TODO
# required_version: 2.7.0

enabled_site_setting :topic_gallery_enabled

register_asset "stylesheets/topic-gallery.scss"

module ::DiscourseTopicGallery
  PLUGIN_NAME = "discourse-topic-gallery"
end

after_initialize do
  require_dependency File.expand_path(
                       "../app/controllers/discourse_topic_gallery/topic_gallery_controller.rb",
                       __FILE__,
                     )

  Discourse::Application.routes.prepend do
    constraints(->(req) { !req.path.end_with?(".json") }) do
      get "t/:slug/:topic_id/gallery" => "topics#show", :constraints => { topic_id: /\d+/ }
      get "t/:topic_id/gallery" => "topics#show", :constraints => { topic_id: /\d+/ }
    end
  end

  add_to_serializer(:current_user, :can_view_topic_gallery) do
    object.in_any_groups?(SiteSetting.topic_gallery_allowed_groups_map)
  end

  Discourse::Application.routes.append do
    scope constraints: { topic_id: /\d+/ } do
      get "/topic-gallery/:topic_id" => "discourse_topic_gallery/topic_gallery#show"
      get "t/:slug/:topic_id/gallery" => "discourse_topic_gallery/topic_gallery#show"
      get "t/:topic_id/gallery" => "discourse_topic_gallery/topic_gallery#show"
    end
  end
end
