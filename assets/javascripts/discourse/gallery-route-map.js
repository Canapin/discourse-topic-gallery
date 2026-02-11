export default function () {
  this.route("topicGallery", { path: "/gallery/:slug/:id" });
  this.route("topicGallerySlugless", { path: "/gallery/:id" });
}
