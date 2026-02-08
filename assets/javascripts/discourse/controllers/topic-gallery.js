import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

// Manages gallery state: the image list, pagination, loading flag, and filters.
// Each filter change triggers a fresh fetch; "load more" appends the next page.
// Query params are managed manually (not via Ember's queryParams) to avoid
// route re-entry on every filter change.
export default class TopicGalleryController extends Controller {
  @service router;

  @tracked images = [];
  @tracked hasMore = false;
  @tracked isLoading = false;
  @tracked total = 0;
  @tracked title = "";
  @tracked slug = "";
  @tracked username = "";
  @tracked from_date = "";
  @tracked to_date = "";
  @tracked post_number = "";
  @tracked filtersVisible = false;

  page = 0;
  topicId = null;
  _fetchId = 0;
  _filterTimer = null;
  _pendingParams = null;

  _scheduleFetch() {
    cancel(this._filterTimer);
    this._filterTimer = later(this, this.fetchImages, 50);
  }

  setupModel(model) {
    this.topicId = model.id;
    this.slug = model.slug;
    this.images = [];
    this.total = 0;
    this.isLoading = true;

    const pending = this._pendingParams;
    this._pendingParams = null;

    if (pending) {
      this.username = pending.username || "";
      this.from_date = pending.from_date || "";
      this.to_date = pending.to_date || "";
      this.post_number = pending.post_number || "";
    } else {
      const url = new URL(window.location.href);
      this.username = url.searchParams.get("username") || "";
      this.from_date = url.searchParams.get("from_date") || "";
      this.to_date = url.searchParams.get("to_date") || "";
      this.post_number = url.searchParams.get("post_number") || "";
    }

    this.fetchImages();
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
    if (this.post_number) {
      params.set("post_number", this.post_number);
    }
    return params;
  }

  updateBrowserUrl() {
    const base = `/t/${this.slug}/${this.topicId}/gallery`;
    const qs = this._filterParams.toString();
    window.history.replaceState(null, "", `${base}${qs ? `?${qs}` : ""}`);
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
      this.images = result.images;
      this.hasMore = result.hasMore;
      this.page = result.page;
      this.total = result.total;
      this.title = result.title;
      this.updateBrowserUrl();
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

  get hasFilters() {
    return this.username || this.from_date || this.to_date || this.post_number;
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
