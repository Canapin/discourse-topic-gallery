# frozen_string_literal: true

# name: discourse-topic-gallery
# about: Adds a gallery view to topics.
# meta_topic_id: 394953
# version: 0.0.2
# authors: Canapin & AI
# url: https://github.com/Canapin/discourse-topic-gallery
# required_version: 2.7.0

enabled_site_setting :topic_gallery_enabled

register_svg_icon "images"
register_asset "stylesheets/topic-gallery.scss"

module ::DiscourseTopicGallery
  PLUGIN_NAME = "discourse-topic-gallery"
end

after_initialize do
  require_dependency File.expand_path(
                       "../app/controllers/discourse_topic_gallery/topic_gallery_controller.rb",
                       __FILE__,
                     )

  # HTML routes: serve the normal topic page (Ember handles the /gallery path client-side)
  Discourse::Application.routes.prepend do
    constraints(->(req) { !req.path.end_with?(".json") }) do
      get "t/:slug/:topic_id/gallery" => "topics#show", :constraints => { topic_id: /\d+/ }
      get "t/:topic_id/gallery" => "topics#show", :constraints => { topic_id: /\d+/ }
    end
  end

  # Expose gallery permission to the client so the UI can show/hide the button
  add_to_serializer(:current_user, :can_view_topic_gallery) do
    object.in_any_groups?(SiteSetting.topic_gallery_allowed_groups_map)
  end

  add_to_serializer(:site, :can_view_topic_gallery) do
    allowed = SiteSetting.topic_gallery_allowed_groups_map
    if scope.user
      scope.user.in_any_groups?(allowed)
    else
      allowed.include?(Group::AUTO_GROUPS[:everyone])
    end
  end

  # JSON API routes: return gallery data (images, pagination, metadata)
  Discourse::Application.routes.append do
    scope constraints: { topic_id: /\d+/ } do
      get "/topic-gallery/:topic_id" => "discourse_topic_gallery/topic_gallery#show"
      get "t/:slug/:topic_id/gallery" => "discourse_topic_gallery/topic_gallery#show"
      get "t/:topic_id/gallery" => "discourse_topic_gallery/topic_gallery#show"
    end
  end
end
