User.find_or_create_by!(email: "joseph.caruso.pc@gmail.com") do |u|
  u.name       = "Joe Caruso"
  u.google_uid = "pending_google_sso"
  u.role       = :admin
end
