# Complex fixture: ~300 lines with nested classes, modules, and various edge cases
# frozen_string_literal: true

module ApplicationServices
  module Authentication
    class UserAuthenticator
      attr_reader :user, :session

      def initialize(user, session)
        @user = user
        @session = session
      end

      def authenticate(password)
        return false unless user_valid?
        return false unless password_matches?(password)

        create_session_token
        log_authentication_attempt(success: true)
        true
      end

      def logout
        invalidate_session
        clear_cookies
      end

      def refresh_token
        return nil unless session_valid?

        generate_new_token
      end

      private

      def user_valid?
        user && user.active? && !user.locked?
      end

      def password_matches?(password)
        BCrypt::Password.new(user.password_digest) == password
      end

      def create_session_token
        @token = SecureRandom.hex(32)
        session[:auth_token] = @token
        store_token_in_redis(@token)
      end

      def invalidate_session
        session.delete(:auth_token)
        remove_token_from_redis
      end

      def clear_cookies
        # Implementation details
      end

      def session_valid?
        session[:auth_token].present? && token_not_expired?
      end

      def token_not_expired?
        redis_token_ttl > 0
      end

      def generate_new_token
        old_token = session[:auth_token]
        new_token = SecureRandom.hex(32)
        rotate_token(old_token, new_token)
        new_token
      end

      def store_token_in_redis(token)
        Redis.current.setex("auth:#{user.id}", 3600, token)
      end

      def remove_token_from_redis
        Redis.current.del("auth:#{user.id}")
      end

      def redis_token_ttl
        Redis.current.ttl("auth:#{user.id}")
      end

      def rotate_token(old_token, new_token)
        remove_token_from_redis
        store_token_in_redis(new_token)
        log_token_rotation(old_token, new_token)
      end

      def log_authentication_attempt(success:)
        Rails.logger.info("Auth attempt for user #{user.id}: #{success}")
      end

      def log_token_rotation(_old_token, _new_token)
        Rails.logger.debug("Token rotated for user #{user.id}")
      end
    end

    class TokenValidator
      ALGORITHM = 'HS256'
      TOKEN_EXPIRY = 3600

      def initialize(secret_key)
        @secret_key = secret_key
      end

      def validate(token)
        decode_token(token)
      rescue JWT::DecodeError => e
        handle_decode_error(e)
        nil
      end

      def generate(payload)
        JWT.encode(enhanced_payload(payload), @secret_key, ALGORITHM)
      end

      private

      def decode_token(token)
        JWT.decode(token, @secret_key, true, algorithm: ALGORITHM).first
      end

      def enhanced_payload(payload)
        payload.merge(
          exp: Time.now.to_i + TOKEN_EXPIRY,
          iat: Time.now.to_i,
          jti: SecureRandom.uuid
        )
      end

      def handle_decode_error(error)
        Rails.logger.warn("JWT decode error: #{error.message}")
        notify_security_team(error) if suspicious_error?(error)
      end

      def suspicious_error?(error)
        error.message.include?('Signature verification')
      end

      def notify_security_team(error)
        SecurityMailer.suspicious_activity(error).deliver_later
      end
    end
  end

  module Authorization
    class PermissionChecker
      def initialize(user, resource)
        @user = user
        @resource = resource
      end

      def can_read?
        has_permission?(:read)
      end

      def can_write?
        has_permission?(:write)
      end

      def can_delete?
        has_permission?(:delete) && admin_or_owner?
      end

      def can_manage?
        admin?
      end

      private

      def has_permission?(action)
        return true if admin?
        return false unless @user.permissions

        @user.permissions.include?(permission_key(action))
      end

      def permission_key(action)
        "#{@resource.class.name.underscore}:#{action}"
      end

      def admin?
        @user.role == 'admin'
      end

      def admin_or_owner?
        admin? || owner?
      end

      def owner?
        @resource.respond_to?(:user_id) && @resource.user_id == @user.id
      end
    end

    class RoleManager
      ROLES = %w[guest user moderator admin superadmin].freeze

      attr_reader :user

      def initialize(user)
        @user = user
      end

      def assign_role(role)
        return false unless valid_role?(role)
        return false unless can_assign_role?(role)

        update_user_role(role)
        notify_role_change(role)
        true
      end

      def promote
        next_role = ROLES[current_role_index + 1]
        assign_role(next_role) if next_role
      end

      def demote
        prev_role = ROLES[current_role_index - 1]
        assign_role(prev_role) if prev_role && current_role_index > 0
      end

      private

      def valid_role?(role)
        ROLES.include?(role)
      end

      def can_assign_role?(role)
        # Superadmin can only be assigned by another superadmin
        return false if role == 'superadmin' && !Current.user&.superadmin?

        true
      end

      def current_role_index
        ROLES.index(user.role) || 0
      end

      def update_user_role(role)
        user.update!(role: role)
        clear_permission_cache
      end

      def clear_permission_cache
        Rails.cache.delete("user:#{user.id}:permissions")
      end

      def notify_role_change(new_role)
        UserMailer.role_changed(user, new_role).deliver_later
        AuditLog.create!(
          action: 'role_change',
          user: user,
          details: { new_role: new_role, changed_by: Current.user&.id }
        )
      end
    end
  end

  class ServiceResult
    attr_reader :success, :data, :errors

    def initialize(success:, data: nil, errors: [])
      @success = success
      @data = data
      @errors = errors
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    class << self
      def success(data = nil)
        new(success: true, data: data)
      end

      def failure(errors)
        new(success: false, errors: Array(errors))
      end

      private

      def build_from_exception(exception)
        failure(exception.message)
      end

      def wrap_errors(errors)
        errors.map { |e| normalize_error(e) }
      end

      def normalize_error(error)
        case error
        when String then error
        when StandardError then error.message
        else error.to_s
        end
      end
    end
  end

  module Concerns
    module Cacheable
      def cache_key
        "#{self.class.name}:#{id}:#{updated_at.to_i}"
      end

      def cached_data
        Rails.cache.fetch(cache_key, expires_in: cache_ttl) do
          compute_cached_data
        end
      end

      private

      def cache_ttl
        1.hour
      end

      def compute_cached_data
        raise NotImplementedError, "#{self.class} must implement #compute_cached_data"
      end

      def invalidate_cache
        Rails.cache.delete(cache_key)
        notify_cache_invalidation
      end

      def notify_cache_invalidation
        Rails.logger.debug("Cache invalidated for #{cache_key}")
      end
    end

    module Trackable
      def track_event(event_name, properties = {})
        return unless tracking_enabled?

        enqueue_tracking_job(event_name, properties)
      end

      private

      def tracking_enabled?
        Rails.env.production? || ENV['FORCE_TRACKING']
      end

      def enqueue_tracking_job(event_name, properties)
        TrackingJob.perform_later(
          event: event_name,
          user_id: current_user_id,
          properties: enriched_properties(properties),
          timestamp: Time.current
        )
      end

      def current_user_id
        Current.user&.id
      end

      def enriched_properties(properties)
        properties.merge(
          source: self.class.name,
          environment: Rails.env
        )
      end
    end
  end
end
