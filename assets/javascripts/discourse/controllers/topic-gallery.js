import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class TopicGalleryController extends Controller {
  @service router;

  @tracked images = [];
  @tracked hasMore = false;
  @tracked isLoading = false;
  @tracked total = 0;
  @tracked postsCount = 0;
  @tracked title = "";
  @tracked slug = "";
  @tracked username = "";
  @tracked from_date = "";
  @tracked to_date = "";
  @tracked post_number = "";
  @tracked filtersVisible = false;

  queryParams = ["username", "post_number"];
  page = 0;
  topicId = null;
  _fetchId = 0;
  _filterTimer = null;

  _scheduleFetch() {
    cancel(this._filterTimer);
    this._filterTimer = later(this, this._fetchAndSyncUrl, 50);
  }

  _syncUrl() {
    const params = this._filterParams;
    const qs = params.toString();
    const path = `/gallery/${this.slug}/${this.topicId}${qs ? `?${qs}` : ""}`;
    window.history.replaceState(null, "", path);
  }

  async _fetchAndSyncUrl() {
    await this.fetchImages();
    this._syncUrl();
  }

  setupModel(model) {
    this.topicId = model.id;
    this.slug = model.slug;
    this.from_date = model.from_date || "";
    this.to_date = model.to_date || "";
    this._applyResult(model.result);
  }

  _applyResult(result) {
    this.images = result.images;
    this.hasMore = result.hasMore;
    this.page = result.page;
    this.total = result.total;
    this.postsCount = result.postsCount;
    this.title = result.title;
    this.isLoading = false;
  }

  get _filterParams() {
    const params = new URLSearchParams();
    if (this.username) {
      params.set("username", this.username);
    }
    if (this.from_date) {
      params.set("from_date", this.from_date);
    }
    if (this.to_date) {
      params.set("to_date", this.to_date);
    }
    if (this.hasPostNumberFilter) {
      params.set("post_number", this.post_number);
    }
    return params;
  }

  buildApiUrl(page) {
    const params = this._filterParams;
    if (page > 0) {
      params.set("page", page);
    }
    const qs = params.toString();
    return `/topic-gallery/${this.topicId}${qs ? `?${qs}` : ""}`;
  }

  async fetchImages() {
    const fetchId = ++this._fetchId;
    this.isLoading = true;

    try {
      const result = await ajax(this.buildApiUrl(0));
      if (fetchId !== this._fetchId) {
        return;
      }
      this._applyResult(result);
    } catch (error) {
      if (fetchId !== this._fetchId) {
        return;
      }
      popupAjaxError(error);
    } finally {
      if (fetchId === this._fetchId) {
        this.isLoading = false;
      }
    }
  }

  @action
  async loadMore() {
    if (this.isLoading || !this.hasMore) {
      return;
    }

    this.isLoading = true;

    try {
      const result = await ajax(this.buildApiUrl(this.page + 1));
      this.images = [...this.images, ...result.images];
      this.hasMore = result.hasMore;
      this.page = result.page;
      this.total = result.total;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  get hasPostNumberFilter() {
    return this.post_number && parseInt(this.post_number, 10) > 1;
  }

  get hasFilters() {
    return (
      this.username ||
      this.from_date ||
      this.to_date ||
      this.hasPostNumberFilter
    );
  }

  @action
  clearFilters() {
    this.username = "";
    this.from_date = "";
    this.to_date = "";
    this.post_number = "";
    this._scheduleFetch();
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
    this._scheduleFetch();
  }

  @action
  updatePostNumber(event) {
    this.post_number = event.target.value || "";
    this._scheduleFetch();
  }

  @action
  updateUsername(val) {
    const selected = Array.isArray(val) ? val[0] : val;
    this.username = selected || "";
    this._scheduleFetch();
  }

  @action
  updateFromDate(date) {
    this.from_date = date || "";
    this._scheduleFetch();
  }

  @action
  updateToDate(date) {
    this.to_date = date || "";
    this._scheduleFetch();
  }
}
