# frozen_string_literal: true

module DiscourseTopicGallery
  class TopicGalleryController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    PAGE_SIZE = 30

    def show
      unless current_user&.in_any_groups?(SiteSetting.topic_gallery_allowed_groups_map)
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

      visible_post_ids = visible_posts.pluck(:id).to_set

      all_uploads =
        Upload
          .joins(:posts)
          .where(posts: { id: visible_post_ids })
          .where("uploads.width IS NOT NULL AND uploads.height IS NOT NULL")
          .distinct

      total = all_uploads.count

      uploads =
        all_uploads
          .includes(:user, :optimized_images, :posts)
          .order("posts.post_number ASC")
          .offset(page * PAGE_SIZE)
          .limit(PAGE_SIZE)

      images = serialize_uploads(uploads.to_a, topic, visible_post_ids)

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

    def serialize_uploads(uploads, topic, visible_post_ids)
      uploads.map do |upload|
        post = upload.posts.find { |p| p.topic_id == topic.id && visible_post_ids.include?(p.id) }
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
          postId: post&.id,
          postNumber: post&.post_number,
          postUrl: post ? "/t/#{topic.slug}/#{topic.id}/#{post.post_number}" : nil,
        }
      end
    end
  end
end
