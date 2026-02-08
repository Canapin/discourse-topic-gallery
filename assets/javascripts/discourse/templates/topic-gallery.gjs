import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import DatePicker from "discourse/components/date-picker";
import icon from "discourse/helpers/d-icon";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { i18n } from "discourse-i18n";
import TopicGalleryGrid from "../components/topic-gallery-grid";

<template>
  <div class="topic-gallery-page">
    <div class="topic-gallery-header">
      <h1 data-topic-id={{@controller.topicId}}>
        <a
          href="/t/{{@controller.slug}}/{{@controller.topicId}}"
          class="topic-back-link"
          {{on "click" @controller.navigateToTopic}}
        >{{icon "chevron-left"}}{{@controller.title}}</a>
      </h1>
      <span class="image-count-badge">
        -
        {{@controller.total}}
        {{i18n "discourse_topic_gallery.images"}}</span>
      <DButton
        @action={{@controller.toggleFilters}}
        @icon={{if @controller.filtersVisible "chevron-up" "sliders"}}
        @label="discourse_topic_gallery.filters_button"
        class={{concat
          "btn-default toggle-filters-btn"
          (if @controller.hasFilters " has-active-filters")
        }}
      />
    </div>
    {{#if @controller.post_number}}
      <div class="post-number-chip">
        <span>{{i18n
            "discourse_topic_gallery.from_post"
            number=@controller.post_number
          }}</span>
        <DButton
          @action={{@controller.clearPostNumber}}
          @icon="xmark"
          class="btn-transparent"
        />
      </div>
    {{/if}}
    <div
      class={{concat
        "admin-controls"
        (if @controller.filtersVisible " is-visible")
      }}
    >
      <div class="control-unit">
        <label>{{i18n "discourse_topic_gallery.filter_by_user"}}</label>
        <UserChooser
          @value={{if @controller.username @controller.username null}}
          @onChange={{@controller.updateUsername}}
          @options={{hash
            maximum=1
            excludeCurrentUser=false
            filterPlaceholder="discourse_topic_gallery.user_placeholder"
          }}
        />
      </div>

      <div class="control-unit">
        <label>{{i18n "discourse_topic_gallery.from_date"}}</label>
        <DatePicker
          @value={{@controller.from_date}}
          @onSelect={{@controller.updateFromDate}}
        />
      </div>

      <div class="control-unit">
        <label>{{i18n "discourse_topic_gallery.to_date"}}</label>
        <DatePicker
          @value={{@controller.to_date}}
          @onSelect={{@controller.updateToDate}}
        />
      </div>

      {{#if @controller.hasFilters}}
        <div class="control-unit">
          <label>&#8203;</label>
          <DButton
            @action={{@controller.clearFilters}}
            @icon="xmark"
            @label="discourse_topic_gallery.clear_filters"
            class="btn-default clear-filters-btn"
          />
        </div>
      {{/if}}
    </div>

    <TopicGalleryGrid
      @images={{@controller.images}}
      @hasMore={{@controller.hasMore}}
      @isLoading={{@controller.isLoading}}
      @loadMore={{@controller.loadMore}}
    />
  </div>
</template>
