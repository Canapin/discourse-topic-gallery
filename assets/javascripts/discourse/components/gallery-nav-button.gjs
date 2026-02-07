import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class GalleryNavButton extends Component {
  @service site;
  @service router;

  @action
  openGallery() {
    const topic = this.args.topic;
    this.router.transitionTo("topicGallery", topic.slug, topic.id);
  }

  <template>
    {{#if this.site.can_view_topic_gallery}}
      <DButton
        @action={{this.openGallery}}
        @icon="images"
        @title="discourse_topic_gallery.gallery_button_title"
        class={{@class}}
      />
    {{/if}}
  </template>
}
