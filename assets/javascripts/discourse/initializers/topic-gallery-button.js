import { getOwner } from "@ember/owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import PostMenuGalleryButton from "../components/post-menu-gallery-button";
import { isCategoryExcluded } from "../lib/gallery-category-check";

const GALLERY_PRIORITY = 250;

// Registered twice: once for logged-in users, once for anonymous visitors.
function galleryButtonConfig(anonymousOnly, siteSettings) {
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
      return (
        !this.site.mobileView &&
        this.site.can_view_topic_gallery &&
        !isCategoryExcluded(siteSettings, this.topic.category_id)
      );
    },
  };
}

export default {
  name: "topic-gallery-button",

  initialize() {
    withPluginApi((api) => {
      const siteSettings = api.container.lookup("service:site-settings");
      api.registerTopicFooterButton(galleryButtonConfig(false, siteSettings));
      api.registerTopicFooterButton(galleryButtonConfig(true, siteSettings));

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
