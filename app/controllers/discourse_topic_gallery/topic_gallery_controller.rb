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

      # Get upload IDs with their earliest post_number for ordering
      upload_post_refs =
        UploadReference
          .joins("INNER JOIN posts ON posts.id = upload_references.target_id")
          .joins("INNER JOIN uploads ON uploads.id = upload_references.upload_id")
          .where(target_type: "Post", target_id: visible_posts_sub)
          .where.not(uploads: { width: nil })
          .where.not(uploads: { height: nil })
          .select("upload_references.upload_id", "MIN(posts.post_number) AS min_post_number")
          .group("upload_references.upload_id")
          .order("min_post_number ASC")

      total = upload_post_refs.length

      paginated_refs =
        UploadReference
          .from(upload_post_refs, :refs)
          .select("refs.upload_id", "refs.min_post_number")
          .offset(page * PAGE_SIZE)
          .limit(PAGE_SIZE)

      upload_ids = paginated_refs.map(&:upload_id)

      uploads = Upload.where(id: upload_ids).includes(:user, :optimized_images).index_by(&:id)

      # Get the post info for each upload (earliest visible post)
      post_by_upload =
        UploadReference
          .joins("INNER JOIN posts ON posts.id = upload_references.target_id")
          .where(upload_id: upload_ids, target_type: "Post")
          .where(target_id: visible_posts_sub)
          .select(
            "DISTINCT ON (upload_references.upload_id) upload_references.upload_id",
            "posts.id AS post_id",
            "posts.post_number",
          )
          .order("upload_references.upload_id, posts.post_number ASC")
          .index_by(&:upload_id)

      # Maintain order from paginated_refs
      ordered_uploads = upload_ids.filter_map { |id| uploads[id] }

      images = serialize_uploads(ordered_uploads, topic, post_by_upload)

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
        scope = scope.where.not(user_id: ignored_ids) if ignored_ids.exists?
      end

      scope
    end

    def serialize_uploads(uploads, topic, post_by_upload)
      uploads.map do |upload|
        ref = post_by_upload[upload.id]
        thumb_w = upload.thumbnail_width || upload.width
        thumb_h = upload.thumbnail_height || upload.height
        optimized = OptimizedImage.create_for(upload, thumb_w, thumb_h)
        thumbnail_raw_url = optimized&.url || upload.url

        {
          id: upload.id,
          thumbnailUrl: UrlHelper.cook_url(thumbnail_raw_url, secure: upload.secure?, local: true),
          url: UrlHelper.cook_url(upload.url, secure: upload.secure?, local: true),
          width: upload.width,
          height: upload.height,
          filesize: upload.human_filesize,
          filename: upload.original_filename,
          downloadUrl: upload.short_path,
          username: upload.user&.username,
          postId: ref&.post_id,
          postNumber: ref&.post_number,
          postUrl: ref ? "/t/#{topic.slug}/#{topic.id}/#{ref.post_number}" : nil,
        }
      end
    end
  end
end
