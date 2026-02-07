# frozen_string_literal: true

module DiscourseTopicGallery
  class TopicGalleryController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    PAGE_SIZE = 30

    def show
      allowed_groups = SiteSetting.topic_gallery_allowed_groups_map
      everyone_allowed = allowed_groups.include?(Group::AUTO_GROUPS[:everyone])
      unless everyone_allowed || current_user&.in_any_groups?(allowed_groups)
        raise Discourse::InvalidAccess
      end

      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless topic
      guardian.ensure_can_see!(topic)

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
          rescue StandardError
            nil
          end
        visible_posts = visible_posts.where("posts.created_at >= ?", from.beginning_of_day) if from
      end

      if params[:to_date].present?
        to =
          begin
            Date.parse(params[:to_date])
          rescue StandardError
            nil
          end
        visible_posts = visible_posts.where("posts.created_at <= ?", to.end_of_day) if to
      end

      visible_posts_sub = visible_posts.select(:id)

      # Exclude uploads that also have a non-Post reference (e.g. CustomEmoji,
      # UserAvatar, ThemeField, etc.) — these are system/asset uploads that
      # happen to appear in post content, not user-submitted images.
      non_content_exclusion = <<~SQL
        NOT EXISTS (
          SELECT 1 FROM upload_references ur2
          WHERE ur2.upload_id = upload_references.upload_id
            AND ur2.target_type != 'Post'
        )
      SQL

      # Single query: fetch paginated refs with total via window function
      refs_with_total =
        UploadReference
          .joins("INNER JOIN posts ON posts.id = upload_references.target_id")
          .joins("INNER JOIN uploads ON uploads.id = upload_references.upload_id")
          .where(target_type: "Post", target_id: visible_posts_sub)
          .where.not(uploads: { width: nil })
          .where.not(uploads: { height: nil })
          .where("uploads.width >= ?", SiteSetting.topic_gallery_minimum_image_size)
          .where("uploads.height >= ?", SiteSetting.topic_gallery_minimum_image_size)
          .where(non_content_exclusion)
          .select(
            "upload_references.upload_id",
            "upload_references.id AS ref_id",
            "posts.id AS post_id",
            "posts.post_number",
            "COUNT(*) OVER() AS total_count",
          )
          .order("posts.post_number ASC, upload_references.id ASC")
          .offset(page * PAGE_SIZE)
          .limit(PAGE_SIZE)

      refs_array = refs_with_total.to_a
      total = refs_array.first&.total_count.to_i
      upload_ids = refs_array.map(&:upload_id)

      uploads = Upload.where(id: upload_ids).includes(:user, :optimized_images).index_by(&:id)

      images = serialize_uploads_from_refs(refs_array, uploads, topic)

      render json: {
               title: topic.title,
               slug: topic.slug,
               id: topic.id,
               images: images,
               page: page,
               hasMore: ((page + 1) * PAGE_SIZE) < total,
               total: total,
             }
    end

    private

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

    def serialize_uploads_from_refs(refs, uploads, topic)
      refs
        .map do |ref|
          upload = uploads[ref.upload_id]
          next unless upload

          thumb_w = upload.thumbnail_width || upload.width
          thumb_h = upload.thumbnail_height || upload.height
          ext = ".#{upload.extension}"

          # Use preloaded optimized_images to avoid per-row queries
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
            filename: upload.original_filename,
            downloadUrl: upload.short_path,
            username: upload.user&.username,
            postId: ref.post_id,
            postNumber: ref.post_number,
            postUrl: "/t/#{topic.slug}/#{topic.id}/#{ref.post_number}",
          }
        end
        .compact
    end
  end
end
