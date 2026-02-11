import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { isCategoryExcluded } from "../lib/gallery-category-check";

export default class PostMenuGalleryButton extends Component {
  @service router;
  @service site;
  @service siteSettings;

  get showButton() {
    return (
      this.site.can_view_topic_gallery &&
      !isCategoryExcluded(this.siteSettings, this.args.post.topic.category_id)
    );
  }

  @action
  openGallery() {
    const post = this.args.post;
    const topic = post.topic;

    this.router.transitionTo("topicGallery", topic.slug, topic.id, {
      queryParams: {
        post_number: post.post_number > 1 ? String(post.post_number) : "",
      },
    });
  }

  <template>
    {{#if this.showButton}}
      <DButton
        class="post-action-menu__gallery gallery"
        ...attributes
        @action={{this.openGallery}}
        @icon="images"
        @label={{if @showLabel "discourse_topic_gallery.gallery_button_label"}}
        @title="discourse_topic_gallery.gallery_button_title"
      />
    {{/if}}
  </template>
}
