class Invite < ApplicationRecord
  belongs_to :household
  belongs_to :created_by, class_name: "User"
  belongs_to :accepted_by, class_name: "User", optional: true

  STATUSES = %w[pending accepted expired revoked].freeze

  before_validation :generate_token, on: :create

  validates :token,    presence: true, uniqueness: true
  validates :status,   presence: true, inclusion: { in: STATUSES }
  validates :max_uses, numericality: { greater_than: 0 }

  scope :pending,  -> { where(status: "pending") }
  scope :accepted, -> { where(status: "accepted") }

  def usable?
    status == "pending" &&
      use_count < max_uses &&
      (expires_at.nil? || expires_at.future?)
  end

  def accept!(user)
    return false unless usable?
    return false if email.present? && email.downcase != user.email.downcase

    transaction do
      increment!(:use_count)
      update!(
        accepted_by: user,
        accepted_at: Time.current,
        status:      use_count >= max_uses ? "accepted" : "pending"
      )
      household.household_memberships.find_or_create_by!(user: user) do |m|
        m.role = "member"
      end
    end
    true
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end
end
