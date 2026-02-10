import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class TopicGalleryRoute extends DiscourseRoute {
  async model(params) {
    const id = parseInt(params.id, 10);
    const slug = params.slug;

    // When the post-menu button sets _pendingParams, the controller will
    // fetch with those filters itself — no need to pre-fetch here.
    const controller = this.controllerFor("topic-gallery");
    if (controller._pendingParams) {
      return { id, slug };
    }

    const qs = new URLSearchParams(window.location.search);
    qs.delete("page");
    const qsStr = qs.toString();
    const url = `/topic-gallery/${id}${qsStr ? `?${qsStr}` : ""}`;

    const result = await ajax(url);
    return { id, slug, result };
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.filtersVisible = false;
    }
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setupModel(model);
  }
}
