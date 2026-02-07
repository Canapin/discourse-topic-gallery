import { getOwner } from "@ember/owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import PostMenuGalleryButton from "../components/post-menu-gallery-button";

const GALLERY_PRIORITY = 250;

// Builds the config for the topic footer "Gallery" button.
// Registered twice: once for logged-in users, once for anonymous visitors.
function galleryButtonConfig(anonymousOnly) {
  return {
    id: anonymousOnly ? "topic-gallery-anon" : "topic-gallery",
    icon: "images",
    priority: GALLERY_PRIORITY,
    label: "discourse_topic_gallery.gallery_button_label",
    title: "discourse_topic_gallery.gallery_button_title",
    anonymousOnly,
    action() {
      const topic = this.topic;
      const router = getOwner(this).lookup("service:router");
      router.transitionTo("topicGallery", topic.slug, topic.id);
    },
    classNames: ["topic-gallery"],
    dropdown() {
      return this.site.mobileView;
    },
    displayed() {
      return !this.site.mobileView && this.site.can_view_topic_gallery;
    },
  };
}

// Registers gallery buttons in two places:
// 1. Topic footer (the bar below the last post) — always registered if user has access
// 2. Post action menu (per-post "..." area) — only if the site setting is enabled
export default {
  name: "topic-gallery-button",

  initialize() {
    withPluginApi((api) => {
      api.registerTopicFooterButton(galleryButtonConfig(false));
      api.registerTopicFooterButton(galleryButtonConfig(true));

      const siteSettings = api.container.lookup("service:site-settings");
      if (siteSettings.topic_gallery_post_menu_button) {
        api.registerValueTransformer(
          "post-menu-buttons",
          ({ value: dag, context: { buttonKeys } }) => {
            dag.add("gallery", PostMenuGalleryButton, {
              before: buttonKeys.SHOW_MORE,
            });
          }
        );
      }
    });
  },
};
