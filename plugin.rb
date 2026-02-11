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
  require_relative "app/controllers/discourse_topic_gallery/topic_gallery_controller"

  # Expose gallery permission to the client so the UI can show/hide the button
  add_to_serializer(:site, :can_view_topic_gallery) do
    allowed = SiteSetting.topic_gallery_allowed_groups_map
    if scope.user
      scope.user.in_any_groups?(allowed)
    else
      allowed.include?(Group::AUTO_GROUPS[:everyone])
    end
  end

  # All routes use /gallery/ prefix — no conflict with Discourse's /t/ catch-all,
  # so no need to prepend. HTML routes serve the Ember app shell; JSON routes
  # return gallery data.
  Discourse::Application.routes.append do
    scope constraints: { topic_id: /\d+/ } do
      constraints(->(req) { !req.path.end_with?(".json") }) do
        get "gallery/:slug/:topic_id" => "discourse_topic_gallery/topic_gallery#page"
        get "gallery/:topic_id" => "discourse_topic_gallery/topic_gallery#page"
      end

      get "/topic-gallery/:topic_id" => "discourse_topic_gallery/topic_gallery#show"
    end
  end
end
