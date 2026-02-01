# frozen_string_literal: true

require "rails_helper"

describe "TopicGalleryController" do
  fab!(:user)
  fab!(:admin)
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
    context "when logged in" do
      before { sign_in(user) }

      it "returns gallery data" do
        get "/topic-gallery/#{topic.id}.json"

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["id"]).to eq(topic.id)
        expect(json["title"]).to eq(topic.title)
        expect(json["total"]).to eq(2)
        expect(json["images"].length).to eq(2)
      end

      it "returns correct image fields" do
        get "/topic-gallery/#{topic.id}.json"

        image = response.parsed_body["images"].find { |i| i["id"] == upload1.id }
        expect(image["width"]).to eq(800)
        expect(image["height"]).to eq(600)
        expect(image["postNumber"]).to eq(1)
        expect(image["username"]).to eq(user.username)
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

      it "sets hasMore correctly" do
        get "/topic-gallery/#{topic.id}.json"

        expect(response.parsed_body["hasMore"]).to eq(false)
      end
    end

    context "with username filter" do
      before { sign_in(user) }

      it "filters by username" do
        get "/topic-gallery/#{topic.id}.json", params: { username: other_user.username }

        json = response.parsed_body
        expect(json["total"]).to eq(1)
        expect(json["images"].first["username"]).to eq(other_user.username)
      end

      it "returns empty for nonexistent username" do
        get "/topic-gallery/#{topic.id}.json", params: { username: "nonexistent_user_xyz" }

        expect(response.parsed_body["total"]).to eq(2)
      end
    end

    context "with date filters" do
      before do
        sign_in(user)
        post1.update!(created_at: 10.days.ago)
        post2.update!(created_at: 2.days.ago)
      end

      it "filters by from_date" do
        get "/topic-gallery/#{topic.id}.json", params: { from_date: 5.days.ago.to_date.to_s }

        json = response.parsed_body
        expect(json["total"]).to eq(1)
        expect(json["images"].first["id"]).to eq(upload2.id)
      end

      it "filters by to_date" do
        get "/topic-gallery/#{topic.id}.json", params: { to_date: 5.days.ago.to_date.to_s }

        json = response.parsed_body
        expect(json["total"]).to eq(1)
        expect(json["images"].first["id"]).to eq(upload1.id)
      end

      it "filters by date range" do
        get "/topic-gallery/#{topic.id}.json",
            params: {
              from_date: 12.days.ago.to_date.to_s,
              to_date: 5.days.ago.to_date.to_s,
            }

        json = response.parsed_body
        expect(json["total"]).to eq(1)
        expect(json["images"].first["id"]).to eq(upload1.id)
      end
    end

    context "with post visibility" do
      before { sign_in(user) }

      it "excludes uploads from deleted posts" do
        post2.update!(deleted_at: Time.zone.now)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end

      it "excludes uploads from hidden posts" do
        post2.update!(hidden: true)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end

      it "excludes whisper posts for regular users" do
        post2.update!(post_type: Post.types[:whisper])
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end

      it "includes whisper posts for staff" do
        SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
        sign_in(admin)
        post2.update!(post_type: Post.types[:whisper])
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id, upload2.id)
      end

      it "excludes uploads from ignored users' posts" do
        Fabricate(:ignored_user, user: user, ignored_user: other_user)
        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).to contain_exactly(upload1.id)
      end
    end

    context "with uploads without dimensions" do
      before { sign_in(user) }

      it "excludes uploads without width/height" do
        no_dims_upload = Fabricate(:upload, user: user, width: nil, height: nil)
        UploadReference.create!(target: post1, upload: no_dims_upload)

        get "/topic-gallery/#{topic.id}.json"

        ids = response.parsed_body["images"].map { |i| i["id"] }
        expect(ids).not_to include(no_dims_upload.id)
      end
    end

    context "with access controls" do
      it "allows anonymous users when everyone group is allowed" do
        get "/topic-gallery/#{topic.id}.json"
        expect(response.status).to eq(200)
      end

      it "returns 403 for anonymous users when restricted to a specific group" do
        group = Fabricate(:group)
        SiteSetting.topic_gallery_allowed_groups = group.id.to_s

        get "/topic-gallery/#{topic.id}.json"
        expect(response.status).to eq(403)
      end

      it "returns 403 when user is not in allowed groups" do
        group = Fabricate(:group)
        SiteSetting.topic_gallery_allowed_groups = group.id.to_s
        sign_in(user)

        get "/topic-gallery/#{topic.id}.json"
        expect(response.status).to eq(403)
      end

      it "returns 404 for nonexistent topic" do
        sign_in(user)
        get "/topic-gallery/999999.json"
        expect(response.status).to eq(404)
      end

      it "returns 403 for topic in restricted category" do
        restricted_category = Fabricate(:private_category, group: Fabricate(:group))
        restricted_topic = Fabricate(:topic, category: restricted_category)
        sign_in(user)

        get "/topic-gallery/#{restricted_topic.id}.json"
        expect(response.status).to eq(403)
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
  end
end
