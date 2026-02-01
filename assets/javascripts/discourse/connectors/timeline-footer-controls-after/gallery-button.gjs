import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class GalleryTimelineButton extends Component {
  @service currentUser;
  @service router;

  @action
  openGallery() {
    const topic = this.args.outletArgs.model;
    this.router.transitionTo("topicGallery", topic.slug, topic.id);
  }

  <template>
    {{#if this.currentUser.can_view_topic_gallery}}
      <DButton
        @action={{this.openGallery}}
        @icon="images"
        @title="discourse_topic_gallery.gallery_button_title"
        class="btn-default gallery-link-btn"
      />
    {{/if}}
  </template>
}
