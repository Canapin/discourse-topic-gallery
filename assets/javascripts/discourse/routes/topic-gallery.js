import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class TopicGalleryRoute extends DiscourseRoute {
  queryParams = {
    username: { refreshModel: true },
    from_date: { refreshModel: true },
    to_date: { refreshModel: true },
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
    const qs = qp.toString();
    return await ajax(`/topic-gallery/${params.id}${qs ? `?${qs}` : ""}`);
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setupModel(model);
  }
}
