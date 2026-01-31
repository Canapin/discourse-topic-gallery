import { hash } from "@ember/helper";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import TopicGalleryGrid from "../components/topic-gallery-grid";

<template>
  <div class="topic-gallery-page">
    <div class="topic-gallery-header">
      <h1>{{@model.title}}</h1>
      <p class="image-count">{{@controller.total}}
        {{i18n "discourse_topic_gallery.images"}}</p>
    </div>

    <div class="topic-gallery-filters">
      <div class="gallery-user-filter">
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
    </div>

    <TopicGalleryGrid
      @images={{@controller.images}}
      @hasMore={{@controller.hasMore}}
      @isLoading={{@controller.isLoading}}
      @loadMore={{@controller.loadMore}}
    />
  </div>
</template>
