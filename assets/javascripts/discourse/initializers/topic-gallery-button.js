import { getOwner } from "@ember/owner";
import { withPluginApi } from "discourse/lib/plugin-api";

const GALLERY_PRIORITY = 250;

export default {
  name: "topic-gallery-button",

  initialize() {
    withPluginApi((api) => {
      api.registerTopicFooterButton({
        id: "topic-gallery",
        icon: "images",
        priority: GALLERY_PRIORITY,
        label: "discourse_topic_gallery.gallery_button_label",
        title: "discourse_topic_gallery.gallery_button_title",
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
          return this.currentUser?.can_view_topic_gallery;
        },
      });
    });
  },
};
