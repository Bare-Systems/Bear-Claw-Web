class User < ApplicationRecord
  enum :role, { viewer: 0, reviewer: 1, operator: 2, admin: 3 }

  validates :email, presence: true, uniqueness: true
  validates :google_uid, presence: true, uniqueness: true
  validates :role, presence: true

  def self.from_google(auth)
    # Find by google_uid first; fall back to email (handles pre-seeded users)
    user = find_by(google_uid: auth.uid) || find_or_initialize_by(email: auth.info.email)
    user.google_uid = auth.uid
    user.name       = auth.info.name
    user.avatar_url = auth.info.image
    user.role     ||= :viewer
    user.save!
    user
  end

  def can_access?(module_name)
    case module_name.to_sym
    when :admin    then admin?
    when :security then admin?
    when :agent    then operator? || admin?
    when :home     then operator? || admin?
    else true
    end
  end
end
