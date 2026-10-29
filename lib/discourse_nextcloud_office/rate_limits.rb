# frozen_string_literal: true

module ::DiscourseNextcloudOffice
  # Frequency and concurrency limits for office requests.
  #
  # Values follow the design table: five mutations per user and thirty per
  # instance per minute, two concurrent mutations per user and eight per
  # instance. Status lookups get their own, higher budget.
  class RateLimits
    MUTATIONS = { user: 5, instance: 30 }.freeze
    STATUS = { user: 30, instance: 120 }.freeze
    CONCURRENCY = { user: 2, instance: 8 }.freeze
    SLOT_TTL = 2.minutes
    SLOT_PREFIX = "discourse-nextcloud-office:slots"

    ACQUIRE_SLOT = DiscourseRedis::EvalHelper.new <<~LUA unless defined?(ACQUIRE_SLOT)
      local now = tonumber(redis.call("TIME")[1])
      for i = 1, 2 do
        redis.call("ZREMRANGEBYSCORE", KEYS[i], "-inf", now)
        if redis.call("ZCARD", KEYS[i]) >= tonumber(ARGV[i]) then
          return 0
        end
      end
      for i = 1, 2 do
        redis.call("ZADD", KEYS[i], now + tonumber(ARGV[3]), ARGV[4])
        redis.call("EXPIRE", KEYS[i], tonumber(ARGV[3]) + 1)
      end
      return 1
    LUA

    RELEASE_SLOT = DiscourseRedis::EvalHelper.new <<~LUA unless defined?(RELEASE_SLOT)
      for i = 1, 2 do
        redis.call("ZREM", KEYS[i], ARGV[1])
      end
      return 1
    LUA

    class << self
      def check_mutation!(user)
        enforce!(user, "mutations", MUTATIONS)
      end

      def check_status!(user)
        enforce!(user, "status", STATUS)
      end

      # Holds a slot for the duration of the block and always releases it.
      def with_slot(user)
        user_key = slot_key("user:#{user.id}")
        instance_key = slot_key("instance")
        keys = [user_key, instance_key]
        token = SecureRandom.uuid
        acquired =
          ACQUIRE_SLOT.eval(
            redis,
            keys,
            [CONCURRENCY[:user], CONCURRENCY[:instance], SLOT_TTL.to_i, token],
          ) == 1
        raise slot_error if !acquired

        begin
          yield
        ensure
          RELEASE_SLOT.eval(redis, keys, [token])
        end
      end

      def slot_count(key)
        redis.zcard(slot_key(key))
      end

      def clear_slots!
        redis.scan_each(match: "#{slot_key("*")}") { |key| redis.del(key) }
      end

      private

      def enforce!(user, name, limits)
        enforce_limiter!(
          RateLimiter.new(
            user,
            "nextcloud_office_#{name}",
            limits[:user],
            1.minute,
            apply_limit_to_staff: true,
          ),
        )
        enforce_limiter!(
          RateLimiter.new(
            nil,
            "nextcloud_office_#{name}_instance",
            limits[:instance],
            1.minute,
            global: true,
          ),
        )
      end

      def enforce_limiter!(limiter)
        limiter.performed!(raise_error: true)
      rescue RateLimiter::LimitExceeded => error
        raise ::DiscourseNextcloudOffice::RequestError.new(
                :rate_limited,
                status: :too_many_requests,
                retry_after: error.available_in,
              )
      end

      def slot_error
        ::DiscourseNextcloudOffice::RequestError.new(
          :too_many_concurrent,
          status: :too_many_requests,
          retry_after: SLOT_TTL.to_i,
        )
      end

      def slot_key(suffix)
        Discourse.redis.namespace_key("#{SLOT_PREFIX}:#{suffix}")
      end

      def redis
        Discourse.redis.without_namespace
      end
    end
  end
end
