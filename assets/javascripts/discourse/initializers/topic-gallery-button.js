import { getOwner } from "@ember/owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import PostMenuGalleryButton from "../components/post-menu-gallery-button";

const GALLERY_PRIORITY = 250;

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
