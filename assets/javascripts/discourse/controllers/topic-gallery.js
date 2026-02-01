import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class TopicGalleryController extends Controller {
  @service router;

  @tracked images = [];
  @tracked hasMore = false;
  @tracked isLoading = false;
  @tracked total = 0;
  @tracked username = "";
  @tracked from_date = "";
  @tracked to_date = "";
  @tracked post_number = "";
  @tracked filtersVisible = false;
  queryParams = ["username", "from_date", "to_date", "post_number"];

  page = 0;
  topicId = null;

  setupModel(model) {
    this.images = model.images;
    this.hasMore = model.hasMore;
    this.total = model.total;
    this.page = model.page;
    this.topicId = model.id;
  }

  buildUrl(page) {
    const params = new URLSearchParams();
    if (page > 0) {
      params.set("page", page);
    }
    if (this.username) {
      params.set("username", this.username);
    }
    if (this.from_date) {
      params.set("from_date", this.from_date);
    }
    if (this.to_date) {
      params.set("to_date", this.to_date);
    }
    if (this.post_number) {
      params.set("post_number", this.post_number);
    }
    const qs = params.toString();
    return `/topic-gallery/${this.topicId}${qs ? `?${qs}` : ""}`;
  }

  async fetchImages() {
    this.isLoading = true;

    try {
      const result = await ajax(this.buildUrl(0));
      this.images = result.images;
      this.hasMore = result.hasMore;
      this.page = result.page;
      this.total = result.total;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async loadMore() {
    if (this.isLoading || !this.hasMore) {
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax(this.buildUrl(this.page + 1));
      this.images = [...this.images, ...result.images];
      this.hasMore = result.hasMore;
      this.page = result.page;
      this.total = result.total;
    } finally {
      this.isLoading = false;
    }
  }

  get hasFilters() {
    return this.username || this.from_date || this.to_date || this.post_number;
  }

  @action
  clearFilters() {
    this.username = "";
    this.from_date = "";
    this.to_date = "";
    this.post_number = "";
    this.fetchImages();
  }

  @action
  navigateToTopic(event) {
    event.preventDefault();
    this.router.transitionTo(event.currentTarget.getAttribute("href"));
  }

  @action
  toggleFilters() {
    this.filtersVisible = !this.filtersVisible;
  }

  @action
  clearPostNumber() {
    this.post_number = "";
    this.fetchImages();
  }

  @action
  updateUsername(val) {
    const selected = Array.isArray(val) ? val[0] : val;
    this.username = selected || "";
    this.fetchImages();
  }

  @action
  updateFromDate(date) {
    this.from_date = date || "";
    this.fetchImages();
  }

  @action
  updateToDate(date) {
    this.to_date = date || "";
    this.fetchImages();
  }
}
