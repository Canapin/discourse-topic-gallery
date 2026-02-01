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
  @tracked username = null;
  @tracked from_date = null;
  @tracked to_date = null;
  queryParams = ["username", "from_date", "to_date"];

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
    return this.username || this.from_date || this.to_date;
  }

  @action
  clearFilters() {
    this.username = null;
    this.from_date = null;
    this.to_date = null;
    this.fetchImages();
  }

  @action
  navigateToTopic(event) {
    event.preventDefault();
    this.router.transitionTo(event.currentTarget.getAttribute("href"));
  }

  @action
  updateUsername(val) {
    const selected = Array.isArray(val) ? val[0] : val;
    this.username = selected || null;
    this.fetchImages();
  }

  @action
  updateFromDate(date) {
    this.from_date = date || null;
    this.fetchImages();
  }

  @action
  updateToDate(date) {
    this.to_date = date || null;
    this.fetchImages();
  }
}
