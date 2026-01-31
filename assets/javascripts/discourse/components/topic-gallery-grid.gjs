import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import lightbox from "discourse/lib/lightbox";

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

export default class TopicGalleryGrid extends Component {
  observer = null;

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

    element.addEventListener("mouseover", onOver);
    element.addEventListener("mouseleave", onLeave);

    run();
    lightbox(element);

    return () => {
      mutationObserver.disconnect();
      resizeObserver.disconnect();
      element.removeEventListener("mouseover", onOver);
      element.removeEventListener("mouseleave", onLeave);
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
                  class="gallery-author"
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
            {{#if @isLoading}}
              <div class="gallery-loading">Loading...</div>
            {{/if}}
          </div>
        {{/if}}
      {{else}}
        <div class="no-images-message">
          <p>No images found in this topic.</p>
        </div>
      {{/if}}
    </div>
  </template>
}
