class HouseholdMembership < ApplicationRecord
  belongs_to :household
  belongs_to :user

  ROLES = %w[owner member].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :household_id, message: "is already a member of this household" }
end
