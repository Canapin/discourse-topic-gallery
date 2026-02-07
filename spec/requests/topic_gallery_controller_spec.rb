# frozen_string_literal: true

require "rails_helper"

describe "TopicGalleryController" do
  fab!(:user)
  fab!(:admin)
  fab!(:moderator)
  fab!(:other_user, :user)
  fab!(:topic) { Fabricate(:topic, user: user) }

  fab!(:post1) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:post2) { Fabricate(:post, topic: topic, user: other_user, post_number: 2) }

  fab!(:upload1) { Fabricate(:upload, user: user, width: 800, height: 600) }
  fab!(:upload2) { Fabricate(:upload, user: other_user, width: 1024, height: 768) }

  before do
    SiteSetting.topic_gallery_enabled = true
    SiteSetting.topic_gallery_allowed_groups = Group::AUTO_GROUPS[:everyone]
    UploadReference.create!(target: post1, upload: upload1)
    UploadReference.create!(target: post2, upload: upload2)
  end

  describe "GET /topic-gallery/:topic_id" do
    context "when plugin is disabled" do
      before { SiteSetting.topic_gallery_enabled = false }

      it "returns 404" do
        sign_in(user)
        get "/topic-gallery/#{topic.id}.json"
        expect(response.status).to eq(404)
      end
    end

    context "with group-based access control" do
      it "allows anonymous users when everyone group is allowed" do
        get "/topic-gallery/#{topic.id}.json"
        expect(response.status).to eq(200)
      end

      it "returns 403 for anonymous users when restricted" do
        group = Fabricate(:group)
        SiteSetting.topic_gallery_allowed_groups = group.id.to_s

        get "/topic-gallery/#{topic.id}.json"
        expect(response.status).to eq(403)
      end

      it "returns 403 for logged-in user not in allowed group" do
        group = Fabricate(:group)
        SiteSetting.topic_gallery_allowed_groups = group.id.to_s
        sign_in(user)

        get "/topic-gallery/#{topic.id}.json"
        expect(response.status).to eq(403)
      end

      it "allows user who is in the allowed group" do
        group = Fabricate(:group)
        group.add(user)
        SiteSetting.topic_gallery_allowed_groups = group.id.to_s
        sign_in(user)

        get "/topic-gallery/#{topic.id}.json"
        expect(response.status).to eq(200)
      end

      it "allows admin even when restricted to a specific group" do
        group = Fabricate(:group)
        SiteSetting.topic_gallery_allowed_groups = group.id.to_s
        sign_in(admin)

        get "/topic-gallery/#{topic.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "with topic-level access" do
      it "returns 404 for nonexistent topic" do
        sign_in(user)
        get "/topic-gallery/999999.json"
        expect(response.status).to eq(404)
      end

      it "returns 403 for topic in a restricted category the user cannot access" do
        restricted_category = Fabricate(:private_category, group: Fabricate(:group))
        restricted_topic = Fabricate(:topic, category: restricted_category)
        sign_in(user)

        get "/topic-gallery/#{restricted_topic.id}.json"
        expect(response.status).to eq(403)
      end

      it "allows access to topic in restricted category when user is in the group" do
        group = Fabricate(:group)
        group.add(user)
        restricted_category = Fabricate(:private_category, group: group)
        restricted_topic = Fabricate(:topic, category: restricted_category)
        Fabricate(:post, topic: restricted_topic, user: user).tap do |p|
          UploadReference.create!(target: p, upload: upload1)
        end
        sign_in(user)

        get "/topic-gallery/#{restricted_topic.id}.json"
        expect(response.status).to eq(200)
      end

      it "returns 403 for a private message topic the user is not part of" do
        pm_topic =
          Fabricate(:topic, archetype: "private_message", user: other_user, category_id: nil)
        Fabricate(:post, topic: pm_topic, user: other_user).tap do |p|
          UploadReference.create!(target: p, upload: upload2)
        end
        sign_in(user)

        get "/topic-gallery/#{pm_topic.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "with post visibility — deleted posts" do
      before { sign_in(user) }

      it "excludes uploads from soft-deleted posts" do
        post2.update!(deleted_at: Time.zone.now)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end

      it "excludes uploads from soft-deleted posts even for admin" do
        sign_in(admin)
        post2.update!(deleted_at: Time.zone.now)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end
    end

    context "with post visibility — hidden (flagged) posts" do
      it "excludes uploads from hidden posts for the post author" do
        post2.update!(hidden: true)
        sign_in(other_user)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end

      it "excludes uploads from hidden posts for regular users" do
        post2.update!(hidden: true)
        sign_in(user)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end

      it "excludes uploads from hidden posts even for admin" do
        post2.update!(hidden: true)
        sign_in(admin)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end
    end

    context "with post visibility — whispers" do
      before { post2.update!(post_type: Post.types[:whisper]) }

      it "excludes whisper images for regular users" do
        sign_in(user)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end

      it "excludes whisper images for anonymous visitors" do
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end

      it "includes whisper images for staff" do
        SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
        sign_in(admin)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id, upload2.id)
      end

      it "includes whisper images for users in whisper-allowed groups" do
        group = Fabricate(:group)
        group.add(user)
        SiteSetting.whispers_allowed_groups = "#{group.id}"
        sign_in(user)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id, upload2.id)
      end
    end

    context "with post visibility — ignored users" do
      it "excludes uploads from posts by ignored users" do
        Fabricate(:ignored_user, user: user, ignored_user: other_user)
        sign_in(user)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end

      it "does not exclude those posts for other users" do
        Fabricate(:ignored_user, user: user, ignored_user: other_user)
        sign_in(admin)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id, upload2.id)
      end

      it "does not filter ignored users for anonymous visitors" do
        Fabricate(:ignored_user, user: user, ignored_user: other_user)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id, upload2.id)
      end
    end

    context "with post visibility — post types" do
      it "excludes small action posts" do
        small_action =
          Fabricate(:post, topic: topic, user: user, post_type: Post.types[:small_action])
        upload3 = Fabricate(:upload, user: user, width: 100, height: 100)
        UploadReference.create!(target: small_action, upload: upload3)
        sign_in(user)

        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).not_to include(upload3.id)
      end

      it "excludes moderator action posts" do
        mod_action =
          Fabricate(:post, topic: topic, user: moderator, post_type: Post.types[:moderator_action])
        upload3 = Fabricate(:upload, user: moderator, width: 100, height: 100)
        UploadReference.create!(target: mod_action, upload: upload3)
        sign_in(user)

        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).not_to include(upload3.id)
      end
    end

    context "with uploads without dimensions" do
      before { sign_in(user) }

      it "excludes uploads missing width" do
        no_width = Fabricate(:upload, user: user, width: nil, height: 100)
        UploadReference.create!(target: post1, upload: no_width)

        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).not_to include(no_width.id)
      end

      it "excludes uploads missing height" do
        no_height = Fabricate(:upload, user: user, width: 100, height: nil)
        UploadReference.create!(target: post1, upload: no_height)

        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).not_to include(no_height.id)
      end
    end

    context "with response format" do
      before { sign_in(user) }

      it "returns correct top-level fields" do
        get "/topic-gallery/#{topic.id}.json"

        json = response.parsed_body
        expect(json["id"]).to eq(topic.id)
        expect(json["title"]).to eq(topic.title)
        expect(json["slug"]).to eq(topic.slug)
        expect(json["total"]).to eq(2)
        expect(json["page"]).to eq(0)
        expect(json["hasMore"]).to eq(false)
      end

      it "returns correct image fields" do
        get "/topic-gallery/#{topic.id}.json"

        image = response.parsed_body["images"].find { |i| i["id"] == upload1.id }
        expect(image["width"]).to eq(800)
        expect(image["height"]).to eq(600)
        expect(image["postNumber"]).to eq(1)
        expect(image["username"]).to eq(user.username)
        expect(image["postUrl"]).to eq("/t/#{topic.slug}/#{topic.id}/1")
        expect(image["url"]).to be_present
        expect(image["thumbnailUrl"]).to be_present
        expect(image["downloadUrl"]).to be_present
        expect(image["filename"]).to be_present
      end

      it "orders images by post_number ASC" do
        get "/topic-gallery/#{topic.id}.json"

        post_numbers = response.parsed_body["images"].map { |i| i["postNumber"] }
        expect(post_numbers).to eq(post_numbers.sort)
      end
    end

    context "with pagination" do
      before { sign_in(user) }

      it "respects page parameter" do
        get "/topic-gallery/#{topic.id}.json", params: { page: 0 }

        expect(response.status).to eq(200)
        expect(response.parsed_body["page"]).to eq(0)
      end

      it "returns empty images for page beyond results" do
        get "/topic-gallery/#{topic.id}.json", params: { page: 100 }

        expect(response.parsed_body["images"]).to be_empty
        expect(response.parsed_body["hasMore"]).to eq(false)
      end

      it "treats negative page as 0" do
        get "/topic-gallery/#{topic.id}.json", params: { page: -5 }

        expect(response.parsed_body["page"]).to eq(0)
        expect(response.parsed_body["images"].length).to eq(2)
      end
    end

    context "with minimum image size filtering" do
      before { sign_in(user) }

      it "excludes images smaller than the minimum size" do
        small_upload = Fabricate(:upload, user: user, width: 16, height: 16)
        UploadReference.create!(target: post1, upload: small_upload)

        SiteSetting.topic_gallery_minimum_image_size = 32
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id, upload2.id)
      end

      it "excludes images where only one dimension is below the minimum" do
        tall_narrow = Fabricate(:upload, user: user, width: 20, height: 400)
        UploadReference.create!(target: post1, upload: tall_narrow)

        SiteSetting.topic_gallery_minimum_image_size = 32
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).not_to include(tall_narrow.id)
      end

      it "includes all images when minimum size is 0" do
        small_upload = Fabricate(:upload, user: user, width: 16, height: 16)
        UploadReference.create!(target: post1, upload: small_upload)

        SiteSetting.topic_gallery_minimum_image_size = 0
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to include(small_upload.id)
      end
    end

    context "with duplicate uploads across posts" do
      before { sign_in(user) }

      it "returns the upload once per post it appears in" do
        UploadReference.create!(target: post2, upload: upload1)

        get "/topic-gallery/#{topic.id}.json"

        images = response.parsed_body["images"]
        upload1_entries = images.select { |i| i["id"] == upload1.id }
        expect(upload1_entries.length).to eq(2)
        expect(upload1_entries.map { |i| i["postNumber"] }).to contain_exactly(1, 2)
      end
    end
  end

  describe "GET /t/:slug/:topic_id/gallery.json" do
    it "returns gallery data via topic URL format" do
      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}/gallery.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["id"]).to eq(topic.id)
      expect(json["images"].length).to eq(2)
    end

    it "enforces the same access controls as the API endpoint" do
      group = Fabricate(:group)
      SiteSetting.topic_gallery_allowed_groups = group.id.to_s
      sign_in(user)

      get "/t/#{topic.slug}/#{topic.id}/gallery.json"
      expect(response.status).to eq(403)
    end
  end
end
