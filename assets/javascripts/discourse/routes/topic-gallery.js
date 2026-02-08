import DiscourseRoute from "discourse/routes/discourse";

// Route handler: extracts the topic ID from the URL. All data fetching
// is handled by the controller's fetchImages() to avoid duplicate requests
// when filters change.
export default class TopicGalleryRoute extends DiscourseRoute {
  model(params) {
    return { id: parseInt(params.id, 10), slug: params.slug };
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
