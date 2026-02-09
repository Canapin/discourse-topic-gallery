import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { isCategoryExcluded } from "../lib/gallery-category-check";

export default class GalleryNavButton extends Component {
  @service site;
  @service siteSettings;
  @service router;

  get showButton() {
    return (
      this.site.can_view_topic_gallery &&
      !isCategoryExcluded(this.siteSettings, this.args.topic.category_id)
    );
  }

  @action
  openGallery() {
    const topic = this.args.topic;
    this.router.transitionTo("topicGallery", topic.slug, topic.id);
  }

  <template>
    {{#if this.showButton}}
      <DButton
        @action={{this.openGallery}}
        @icon="images"
        @title="discourse_topic_gallery.gallery_button_title"
        class={{@class}}
      />
    {{/if}}
  </template>
}
