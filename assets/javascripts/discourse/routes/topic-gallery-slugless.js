import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class TopicGallerySluglessRoute extends DiscourseRoute {
  @service router;

  async beforeModel(transition) {
    const id = parseInt(transition.to.params.id, 10);
    const result = await ajax(`/topic-gallery/${id}`);
    this.router.replaceWith("topicGallery", result.slug, id, {
      queryParams: transition.to.queryParams || {},
    });
  }
}
