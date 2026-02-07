import GalleryNavButton from "../../components/gallery-nav-button";

// Gallery button next to the mobile topic progress bar
<template>
  <GalleryNavButton
    @topic={{@outletArgs.model}}
    @class="btn-default btn-icon gallery-progress-btn"
  />
</template>
