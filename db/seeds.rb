# Pre-seed Joe so he lands as admin on first Google OAuth login.
# All other users are created automatically on first login with the
# default `operator` role — no seed entries needed.
User.find_or_create_by!(email: "joseph.caruso.pc@gmail.com") do |u|
  u.name       = "Joe Caruso"
  u.google_uid = "pending_google_sso"
  u.role       = :admin
end

joe = User.find_by!(email: "joseph.caruso.pc@gmail.com")

household = Household.find_or_create_by!(owner: joe) do |h|
  h.name = "Caruso Home"
end

HouseholdMembership.find_or_create_by!(household: household, user: joe) do |m|
  m.role = "owner"
end
