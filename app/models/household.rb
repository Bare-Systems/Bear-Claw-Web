class Household < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :household_memberships, dependent: :destroy
  has_many :members, through: :household_memberships, source: :user
  has_many :invites, dependent: :destroy

  validates :name, presence: true

  def member?(user)
    household_memberships.exists?(user: user)
  end
end
