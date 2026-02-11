import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-topic-gallery";

export default {
  name: "topic-gallery-admin-plugin-icon",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "images");
    });
  },
};
