import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DatePicker from "discourse/components/date-picker";
import icon from "discourse/helpers/d-icon";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { i18n } from "discourse-i18n";
import TopicGalleryGrid from "../components/topic-gallery-grid";

<template>
  <div class="topic-gallery-page">
    <div class="topic-gallery-header">
      <h1 data-topic-id={{@model.id}}>
        <a
          href="/t/{{@model.slug}}/{{@model.id}}"
          class="topic-back-link"
          {{on "click" @controller.navigateToTopic}}
        >{{icon "chevron-left"}}{{@model.title}}</a>
      </h1>
      <span class="image-count-badge">
        -
        {{@controller.total}}
        {{i18n "discourse_topic_gallery.images"}}</span>
    </div>
    <div class="admin-controls">
      <div class="control-unit">
        <label>{{i18n "discourse_topic_gallery.filter_by_user"}}</label>
        <EmailGroupUserChooser
          @value={{@controller.username}}
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
    </div>

    <TopicGalleryGrid
      @images={{@controller.images}}
      @hasMore={{@controller.hasMore}}
      @isLoading={{@controller.isLoading}}
      @loadMore={{@controller.loadMore}}
    />
  </div>
</template>
