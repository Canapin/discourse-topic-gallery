import GalleryNavButton from "../../components/gallery-nav-button";

// Gallery button at the bottom of the topic timeline (desktop sidebar)
<template>
  <GalleryNavButton
    @topic={{@outletArgs.model}}
    @class="btn-default gallery-link-btn"
  />
</template>
