import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import lightbox from "discourse/lib/lightbox";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

// Applies CSS classes to visually group consecutive images from the same post,
// accounting for the current number of grid columns and row wrapping.
function applyGroupBorders(grid) {
  const cards = Array.from(grid.querySelectorAll(".gallery-card"));
  if (!cards.length) {
    return;
  }

  const cols = getComputedStyle(grid)
    .getPropertyValue("grid-template-columns")
    .split(" ").length;

  cards.forEach((card, index) => {
    const group = card.dataset.postId;
    const col = index % cols;
    const prev = index > 0 ? cards[index - 1].dataset.postId : null;
    const next =
      index < cards.length - 1 ? cards[index + 1].dataset.postId : null;

    const sameGroupLeftInRow = col > 0 && prev === group;
    const isGroupStart = prev !== group;
    const isGroupEnd = next !== group;
    const isGroupFirst = !sameGroupLeftInRow;
    const isRowStart = col === 0 && !isGroupStart;
    const isRowEnd =
      (col === cols - 1 || index === cards.length - 1) && !isGroupEnd;

    card.classList.toggle("group-start", isGroupStart);
    card.classList.toggle("group-end", isGroupEnd);
    card.classList.toggle("group-first", isGroupFirst);
    card.classList.toggle("row-start", isRowStart);
    card.classList.toggle("row-end", isRowEnd);
  });
}

// Renders the image grid with lightbox support, infinite scroll, and
// hover highlighting of same-post image groups.
export default class TopicGalleryGrid extends Component {
  @service router;

  observer = null;

  // Infinite scroll: triggers loadMore when the sentinel element becomes visible
  sentinel = modifier((element) => {
    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          this.args.loadMore?.();
        }
      },
      { rootMargin: "300px" }
    );
    this.observer.observe(element);
    return () => {
      this.observer?.disconnect();
      this.observer = null;
    };
  });

  // Sets up post-group borders, lightbox, hover highlighting, and internal link navigation
  groupBorders = modifier((element) => {
    const run = () => applyGroupBorders(element);

    const mutationObserver = new MutationObserver(() => {
      run();
      lightbox(element);
    });
    mutationObserver.observe(element, { childList: true });

    const resizeObserver = new ResizeObserver(run);
    resizeObserver.observe(element);

    let hoveredGroup = null;

    const onOver = (e) => {
      const card = e.target.closest(".gallery-card");
      const group = card?.dataset.postId ?? null;
      if (group === hoveredGroup) {
        return;
      }
      if (hoveredGroup) {
        element
          .querySelectorAll(".gallery-card.group-hover")
          .forEach((c) => c.classList.remove("group-hover"));
      }
      hoveredGroup = group;
      if (group) {
        element
          .querySelectorAll(`.gallery-card[data-post-id="${group}"]`)
          .forEach((c) => c.classList.add("group-hover"));
      }
    };

    const onLeave = () => {
      if (hoveredGroup) {
        element
          .querySelectorAll(".gallery-card.group-hover")
          .forEach((c) => c.classList.remove("group-hover"));
        hoveredGroup = null;
      }
    };

    const onClick = (e) => {
      if (e.target.closest("[data-user-card]")) {
        return;
      }
      const link = e.target.closest("a.gallery-post-link");
      if (!link) {
        return;
      }
      const href = link.getAttribute("href");
      if (href && DiscourseURL.isInternal(href)) {
        e.preventDefault();
        e.stopPropagation();
        this.router.transitionTo(href);
      }
    };

    element.addEventListener("mouseover", onOver);
    element.addEventListener("mouseleave", onLeave);
    element.addEventListener("click", onClick);

    run();
    lightbox(element);

    return () => {
      mutationObserver.disconnect();
      resizeObserver.disconnect();
      element.removeEventListener("mouseover", onOver);
      element.removeEventListener("mouseleave", onLeave);
      element.removeEventListener("click", onClick);
    };
  });

  <template>
    <div class="topic-gallery-container">
      {{#if @images.length}}
        <div class="gallery-grid" {{this.groupBorders}}>
          {{#each @images as |image|}}
            <div class="gallery-card" data-post-id={{image.postId}}>
              <a
                href={{image.url}}
                class="lightbox image-preview-link"
                title={{image.filename}}
                data-download-href={{image.downloadUrl}}
                data-target-width={{image.width}}
                data-target-height={{image.height}}
              >
                <span class="image-wrapper">
                  <img
                    src={{image.thumbnailUrl}}
                    class="gallery-image"
                    loading="lazy"
                    alt={{image.filename}}
                  />
                </span>
                <span class="informations">{{image.width}}×{{image.height}}
                  {{image.filesize}}</span>
              </a>
              <div class="gallery-meta">
                <a
                  href="/u/{{image.username}}"
                  data-user-card={{image.username}}
                  class="mention"
                >@{{image.username}}</a>
                &nbsp;-&nbsp;
                <a
                  href={{image.postUrl}}
                  class="gallery-post-link"
                >#{{image.postNumber}}</a>
              </div>
            </div>
          {{/each}}
        </div>

        {{#if @hasMore}}
          <div class="gallery-sentinel" {{this.sentinel}}>
            <ConditionalLoadingSpinner @condition={{@isLoading}} />
          </div>
        {{/if}}
      {{else}}
        <div class="no-images-message">
          <p>{{i18n "discourse_topic_gallery.no_images_found"}}</p>
        </div>
      {{/if}}
    </div>
  </template>
}
