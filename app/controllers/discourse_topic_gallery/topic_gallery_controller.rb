# frozen_string_literal: true

module DiscourseTopicGallery
  class TopicGalleryController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    PAGE_SIZE = 30

    # Serves the Ember app shell for direct browser visits.
    # Uses our own action instead of topics#show to avoid slug-correction redirects
    # that would strip the /gallery suffix.
    def page
      find_gallery_topic
      render html: "".html_safe
    end

    def show
      topic = find_gallery_topic

      page = [params[:page].to_i, 0].max
      visible_posts = visible_posts_scope(topic)

      if params[:username].present?
        filter_user = User.find_by_username(params[:username])
        visible_posts = visible_posts.where(user_id: filter_user.id) if filter_user
      end

      if params[:post_number].present?
        visible_posts = visible_posts.where("posts.post_number >= ?", params[:post_number].to_i)
      end

      if params[:from_date].present?
        from =
          begin
            Date.parse(params[:from_date])
          rescue ArgumentError
            nil
          end
        visible_posts = visible_posts.where("posts.created_at >= ?", from.beginning_of_day) if from
      end

      if params[:to_date].present?
        to =
          begin
            Date.parse(params[:to_date])
          rescue ArgumentError
            nil
          end
        visible_posts = visible_posts.where("posts.created_at <= ?", to.end_of_day) if to
      end

      visible_posts_sub = visible_posts.select(:id)

      # Exclude uploads that are also referenced as system assets.
      # Blocked (system assets):
      #   CustomEmoji, UserAvatar, User, UserProfile, ThemeField,
      #   ThemeSetting, ThemeSiteSetting, SiteSetting, Badge, Group
      #
      # Allowed through (user content that may share an upload with a post):
      #   ChatMessage, Draft, PostLocalization, ReviewableQueuedPost, Category
      system_exclusion = <<~SQL
        NOT EXISTS (
          SELECT 1 FROM upload_references ur2
          WHERE ur2.upload_id = upload_references.upload_id
            AND ur2.target_type IN (
              'CustomEmoji', 'UserAvatar', 'User', 'UserProfile',
              'ThemeField', 'ThemeSetting', 'ThemeSiteSetting',
              'SiteSetting', 'Badge', 'Group'
            )
        )
      SQL

      # Base query for all valid upload references
      base_scope =
        UploadReference
          .joins("INNER JOIN posts ON posts.id = upload_references.target_id")
          .joins("INNER JOIN uploads ON uploads.id = upload_references.upload_id")
          .where(target_type: "Post", target_id: visible_posts_sub)
          .where.not(uploads: { width: nil })
          .where.not(uploads: { height: nil })
          .where("uploads.width >= ?", SiteSetting.topic_gallery_minimum_image_size)
          .where("uploads.height >= ?", SiteSetting.topic_gallery_minimum_image_size)
          .where(system_exclusion)

      # Get total count of unique uploads (for pagination)
      total = base_scope.select("uploads.id").distinct.count

      # Use window function to deduplicate in a single pass
      # ROW_NUMBER() assigns 1 to the first occurrence of each upload (by post order)
      ranked_sql =
        base_scope.select(
          "upload_references.upload_id",
          "upload_references.id AS ref_id",
          "posts.id AS post_id",
          "posts.post_number",
          "posts.user_id AS post_user_id",
          "ROW_NUMBER() OVER (PARTITION BY uploads.id ORDER BY posts.post_number, upload_references.id) AS row_num",
        ).to_sql

      # Filter to first occurrence (row_num = 1) and apply pagination
      refs_with_total =
        UploadReference
          .from("(#{ranked_sql}) AS ranked_refs")
          .where("row_num = 1")
          .select("upload_id", "ref_id", "post_id", "post_number", "post_user_id")
          .order("post_number ASC, ref_id ASC")
          .offset(page * PAGE_SIZE)
          .limit(PAGE_SIZE)

      refs_array = refs_with_total.to_a
      upload_ids = refs_array.map(&:upload_id)

      uploads = Upload.where(id: upload_ids).includes(:optimized_images).index_by(&:id)
      post_user_ids = refs_array.map(&:post_user_id).uniq
      post_users = User.where(id: post_user_ids).index_by(&:id)

      images = serialize_uploads_from_refs(refs_array, uploads, post_users, topic)

      render json: {
               title: topic.title,
               slug: topic.slug,
               id: topic.id,
               images: images,
               page: page,
               hasMore: ((page + 1) * PAGE_SIZE) < total,
               total: total,
               postsCount: topic.posts_count,
             }
    end

    private

    def find_gallery_topic
      allowed_groups = SiteSetting.topic_gallery_allowed_groups_map
      everyone_allowed = allowed_groups.include?(Group::AUTO_GROUPS[:everyone])
      unless everyone_allowed || current_user&.in_any_groups?(allowed_groups)
        raise Discourse::NotFound
      end

      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless topic
      raise Discourse::NotFound unless guardian.can_see?(topic)
      if SiteSetting.topic_gallery_excluded_categories_map.include?(topic.category_id)
        raise Discourse::NotFound
      end

      topic
    end

    def visible_posts_scope(topic)
      allowed_types = [Post.types[:regular]]
      allowed_types << Post.types[:whisper] if guardian.can_see_whispers?

      scope =
        Post
          .where(topic_id: topic.id)
          .where(deleted_at: nil)
          .where(hidden: false)
          .where(post_type: allowed_types)

      if current_user
        ignored_ids = IgnoredUser.where(user_id: current_user.id).select(:ignored_user_id)
        scope = scope.where.not(user_id: ignored_ids)
      end

      scope
    end

    def serialize_uploads_from_refs(refs, uploads, post_users, topic)
      refs
        .map do |ref|
          upload = uploads[ref.upload_id]
          next unless upload

          thumb_w = upload.thumbnail_width || upload.width
          thumb_h = upload.thumbnail_height || upload.height
          ext = ".#{upload.extension}"

          optimized =
            upload.optimized_images.detect do |oi|
              oi.width == thumb_w && oi.height == thumb_h && oi.extension == ext
            end
          optimized ||= OptimizedImage.create_for(upload, thumb_w, thumb_h)
          thumbnail_raw_url = optimized&.url || upload.url

          {
            id: upload.id,
            thumbnailUrl:
              UrlHelper.cook_url(thumbnail_raw_url, secure: upload.secure?, local: true),
            url: UrlHelper.cook_url(upload.url, secure: upload.secure?, local: true),
            width: upload.width,
            height: upload.height,
            filesize: upload.human_filesize,
            downloadUrl: upload.short_path,
            username: post_users[ref.post_user_id]&.username,
            postId: ref.post_id,
            postNumber: ref.post_number,
            postUrl: "/t/#{topic.slug}/#{topic.id}/#{ref.post_number}",
          }
        end
        .compact
    end
  end
end
