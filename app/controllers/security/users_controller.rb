module Security
  class UsersController < BaseController
    def index
      @users = ursa_client.get_json("/api/v1/users")["users"]
    end

    def create
      ursa_client.post_json("/api/v1/users", payload: {
        username: params[:username],
        password: params[:password],
        role: params[:role],
        is_active: params[:is_active].present?
      })
      redirect_to security_users_path, notice: "Ursa user created."
    end

    def update
      ursa_client.patch_json("/api/v1/users/#{params[:id]}", payload: {
        role: params[:role],
        is_active: params[:is_active].present?
      })
      redirect_to security_users_path, notice: "Ursa user updated."
    end

    def password
      ursa_client.post_json("/api/v1/users/#{params[:id]}/password", payload: { password: params[:password] })
      redirect_to security_users_path, notice: "Password updated."
    end
  end
end
