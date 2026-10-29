# frozen_string_literal: true

RSpec.describe DiscourseNextcloudOffice::RateLimits do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:staff, :moderator)

  before do
    RateLimiter.enable
    RateLimiter.clear_all_global!
    described_class.clear_slots!
  end

  after do
    RateLimiter.disable
    RateLimiter.clear_all_global!
    described_class.clear_slots!
  end

  def expect_error(error_code)
    yield
  rescue DiscourseNextcloudOffice::RequestError => error
    expect(error.error_code).to eq(error_code)
    error
  else
    raise "expected RequestError #{error_code}"
  end

  describe ".check_mutation!" do
    it "allows five mutations per minute and then rejects with a retry hint" do
      5.times { described_class.check_mutation!(user) }

      error = expect_error("rate_limited") { described_class.check_mutation!(user) }

      expect(error.status).to eq(:too_many_requests)
      expect(error.retry_after).to be > 0
    end

    it "counts other users separately" do
      5.times { described_class.check_mutation!(user) }
      described_class.check_mutation!(other_user)

      expect_error("rate_limited") { described_class.check_mutation!(user) }
    end

    it "also limits staff accounts" do
      5.times { described_class.check_mutation!(staff) }

      expect_error("rate_limited") { described_class.check_mutation!(staff) }
    end

    it "enforces the instance budget across users" do
      6.times do
        member = Fabricate(:user)
        5.times { described_class.check_mutation!(member) }
      end

      expect_error("rate_limited") { described_class.check_mutation!(other_user) }
    end
  end

  describe ".check_status!" do
    it "uses a larger but separate budget" do
      30.times { described_class.check_status!(user) }

      expect_error("rate_limited") { described_class.check_status!(user) }
      expect { described_class.check_mutation!(user) }.not_to raise_error
    end
  end

  describe ".with_slot" do
    def seed_slots(suffix, count)
      key = "#{described_class::SLOT_PREFIX}:#{suffix}"
      count.times { |index| Discourse.redis.zadd(key, Time.now.to_i + 120, "seed-#{index}") }
    end

    it "keeps a replacement lease when an expired owner releases its slot" do
      described_class.with_slot(user) do
        # Simulate expiry and acquisition by another request before ensure.
        described_class.clear_slots!
        seed_slots("instance", 1)
        seed_slots("user:#{user.id}", 1)
      end

      expect(described_class.slot_count("instance")).to eq(1)
      expect(described_class.slot_count("user:#{user.id}")).to eq(1)
    end

    it "allows two parallel operations per user" do
      described_class.with_slot(user) do
        described_class.with_slot(user) do
          expect(described_class.slot_count("user:#{user.id}")).to eq(2)
        end
      end

      expect(described_class.slot_count("user:#{user.id}")).to eq(0)
    end

    it "rejects a third parallel operation for the same user" do
      described_class.with_slot(user) do
        described_class.with_slot(user) do
          expect_error("too_many_concurrent") { described_class.with_slot(user) { nil } }
        end
      end
    end

    it "releases slots when the operation raises" do
      expect { described_class.with_slot(user) { raise "boom" } }.to raise_error("boom")

      expect(described_class.slot_count("user:#{user.id}")).to eq(0)
      expect(described_class.slot_count("instance")).to eq(0)
    end

    it "limits the whole instance to eight parallel operations" do
      seed_slots("instance", 8)

      expect_error("too_many_concurrent") { described_class.with_slot(user) { nil } }

      expect(described_class.slot_count("instance")).to eq(8)
      expect(described_class.slot_count("user:#{user.id}")).to eq(0)
    end

    it "counts eight instance slots as available and the ninth as taken" do
      seed_slots("instance", 7)

      described_class.with_slot(user) { expect(described_class.slot_count("instance")).to eq(8) }

      expect(described_class.slot_count("instance")).to eq(7)
    end
  end
end
