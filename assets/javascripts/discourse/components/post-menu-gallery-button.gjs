import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { isCategoryExcluded } from "../lib/gallery-category-check";

// Gallery button in each post's action menu — opens the gallery filtered to that post
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

    const controller = getOwner(this).lookup("controller:topic-gallery");
    controller._pendingParams = {
      post_number: post.post_number > 1 ? String(post.post_number) : "",
    };

    this.router.transitionTo(`/t/${topic.slug}/${topic.id}/gallery`);
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
