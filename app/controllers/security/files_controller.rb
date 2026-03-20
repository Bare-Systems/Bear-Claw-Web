module Security
  class FilesController < BaseController
    def index
      @filters = params.permit(:session_id).to_h
      @files = ursa_client.get_json("/api/v1/files", params: @filters)["files"]
    end

    def download
      render_ursa_download(ursa_client.download("/api/v1/files/#{params[:id]}/download"))
    end
  end
end
