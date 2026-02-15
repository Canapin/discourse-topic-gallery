import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class TopicGalleryRoute extends DiscourseRoute {
  queryParams = {
    username: { refreshModel: false, replace: true },
    post_number: { refreshModel: false, replace: true },
  };

  async model(params, transition) {
    const id = parseInt(params.id, 10);
    const slug = params.slug;

    const qp = transition.to?.queryParams || {};
    const urlParams = new URLSearchParams(window.location.search);
    const qs = new URLSearchParams();
    for (const [key, value] of Object.entries(qp)) {
      if (value) {
        qs.set(key, value);
      }
    }
    for (const key of ["from_date", "to_date"]) {
      const value = urlParams.get(key);
      if (value) {
        qs.set(key, value);
      }
    }
    const qsStr = qs.toString();
    const url = `/topic-gallery/${id}${qsStr ? `?${qsStr}` : ""}`;

    const result = await ajax(url);
    return {
      id,
      slug,
      result,
      from_date: qs.get("from_date") || "",
      to_date: qs.get("to_date") || "",
    };
  }

  // Ember keeps queryParams sticky across transitions by default.
  // Reset them when leaving the gallery so returning shows the full gallery.
  resetController(controller, isExiting) {
    if (isExiting) {
      controller.filtersVisible = false;
      controller.username = "";
      controller.from_date = "";
      controller.to_date = "";
      controller.post_number = "";
    }
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    window.scrollTo(0, 0);
    controller.setupModel(model);
  }
}
