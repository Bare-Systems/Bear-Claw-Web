class User < ApplicationRecord
  enum :role, { viewer: 0, reviewer: 1, operator: 2, admin: 3 }

  has_many :devices, dependent: :nullify
  has_many :household_memberships, dependent: :destroy
  has_many :households, through: :household_memberships
  has_many :owned_households, class_name: "Household", foreign_key: :owner_id, dependent: :nullify

  validates :email, presence: true, uniqueness: true
  validates :google_uid, presence: true, uniqueness: true
  validates :role, presence: true

  InviteRequiredError      = Class.new(StandardError)
  InviteEmailMismatchError = Class.new(StandardError)
  SupportAccessDeniedError = Class.new(StandardError)

  def self.from_google(auth, invite: nil)
    from_omniauth(auth, invite: invite)
  end

  def self.from_omniauth(auth, invite: nil)
    email = auth.info.email.to_s.downcase
    uid   = omniauth_uid(auth)

    raise SupportAccessDeniedError if auth.provider.to_s == "oidc" && !support_email_allowed?(email)

    existing = find_by(google_uid: uid) || find_by(email: email)

    if existing
      existing.update!(
        google_uid: uid,
        name:       auth.info.name.presence || existing.name,
        avatar_url: auth.info.image.presence || existing.avatar_url
      )
      # If they arrived via an invite link, accept it to add household membership
      invite&.accept!(existing) if invite&.usable?
      return existing
    end

    # New user — must have a valid invite
    raise InviteRequiredError    unless invite&.usable?
    raise InviteEmailMismatchError if invite.email.present? && invite.email.downcase != email

    user = new(
      email:      email,
      google_uid: uid,
      name:       auth.info.name.presence || email,
      avatar_url: auth.info.image,
      role:       :viewer
    )
    user.save!
    invite.accept!(user)
    user
  end

  def self.omniauth_uid(auth)
    provider = auth.provider.to_s
    uid = auth.uid.to_s

    provider == "google_oauth2" ? uid : "#{provider}:#{uid}"
  end

  def self.support_email_allowed?(email)
    allowlist = ENV.fetch("OIDC_ALLOWED_EMAILS", "")
      .split(",")
      .map { |entry| entry.strip.downcase }
      .reject(&:blank?)

    return true if allowlist.empty?

    allowlist.include?(email)
  end

  def can_access?(module_name)
    case module_name.to_sym
    when :admin    then admin?
    when :security then admin?
    when :agent    then operator? || admin?
    when :home     then viewer? || operator? || admin?
    when :finances then operator? || admin?
    else true
    end
  end
end
