import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class TopicGalleryRoute extends DiscourseRoute {
  queryParams = {
    username: { refreshModel: true },
  };

  async model(params) {
    let url = `/topic-gallery/${params.id}`;
    if (params.username) {
      url += `?username=${encodeURIComponent(params.username)}`;
    }
    return await ajax(url);
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setupModel(model);
  }
}
