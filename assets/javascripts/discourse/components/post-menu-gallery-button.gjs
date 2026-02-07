import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

// Gallery button in each post's action menu — opens the gallery filtered to that post
export default class PostMenuGalleryButton extends Component {
  @service router;
  @service site;

  @action
  openGallery() {
    const post = this.args.post;
    const topic = post.topic;

    const qp = post.post_number > 1 ? { post_number: post.post_number } : {};
    this.router.transitionTo("topicGallery", topic.slug, topic.id, {
      queryParams: qp,
    });
  }

  <template>
    {{#if this.site.can_view_topic_gallery}}
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
