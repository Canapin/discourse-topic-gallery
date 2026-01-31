import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class TopicGalleryController extends Controller {
  @tracked images = [];
  @tracked hasMore = false;
  @tracked isLoading = false;
  @tracked total = 0;
  @tracked username = null;
  queryParams = ["username"];

  page = 0;
  topicId = null;

  setupModel(model) {
    this.images = model.images;
    this.hasMore = model.hasMore;
    this.total = model.total;
    this.page = model.page;
    this.topicId = model.id;
  }

  @action
  async loadMore() {
    if (this.isLoading || !this.hasMore) {
      return;
    }

    this.isLoading = true;

    try {
      const nextPage = this.page + 1;
      let url = `/topic-gallery/${this.topicId}?page=${nextPage}`;
      if (this.username) {
        url += `&username=${encodeURIComponent(this.username)}`;
      }
      const result = await ajax(url);
      this.images = [...this.images, ...result.images];
      this.hasMore = result.hasMore;
      this.page = result.page;
      this.total = result.total;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  updateUsername(val) {
    const selected = Array.isArray(val) ? val[0] : val;
    this.username = selected || null;
  }
}
