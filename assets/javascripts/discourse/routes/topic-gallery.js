import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class TopicGalleryRoute extends DiscourseRoute {
  queryParams = {
    username: { replace: true },
    from_date: { replace: true },
    to_date: { replace: true },
    post_number: { replace: true },
  };

  async model(params) {
    const qp = new URLSearchParams();
    if (params.username) {
      qp.set("username", params.username);
    }
    if (params.from_date) {
      qp.set("from_date", params.from_date);
    }
    if (params.to_date) {
      qp.set("to_date", params.to_date);
    }
    if (params.post_number) {
      qp.set("post_number", params.post_number);
    }
    const qs = qp.toString();
    return await ajax(`/topic-gallery/${params.id}${qs ? `?${qs}` : ""}`);
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.username = "";
      controller.from_date = "";
      controller.to_date = "";
      controller.post_number = "";
    }
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setupModel(model);
  }
}
