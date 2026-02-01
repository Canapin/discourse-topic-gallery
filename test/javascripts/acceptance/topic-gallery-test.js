import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic Gallery", function (needs) {
  needs.user();
  needs.settings({ topic_gallery_enabled: true });

  needs.pretender((server, helper) => {
    const topicResponse = topicFixtures["/t/280/1.json"];
    server.get("/t/280.json", () => helper.response(topicResponse));

    server.get("/topic-gallery/:topic_id", () =>
      helper.response({
        id: 280,
        title: "Internationalization / localization",
        slug: "internationalization-localization",
        images: [],
        page: 0,
        hasMore: false,
        total: 0,
      })
    );
  });

  test("visiting the gallery route displays the topic title", async function (assert) {
    await visit("/t/internationalization-localization/280/gallery");

    assert
      .dom(".topic-gallery-page h1")
      .hasText("Internationalization / localization");
  });

  test("can navigate to gallery from topic page", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await visit("/t/internationalization-localization/280/gallery");

    assert.dom(".topic-gallery-page").exists();
    assert
      .dom(".topic-gallery-page h1")
      .hasText("Internationalization / localization");
  });
});
