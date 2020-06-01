class Admin::EditorPageDirectoriesController < AdminController
  before_action :set_editor_page_directory, only: %i(edit update destroy)

  def new
    @editor_page_directory = EditorPageDirectory.new
  end

  def create
    @editor_page_directory = EditorPageDirectory.new(editor_page_directory_params)

    if @editor_page_directory.save
      redirect_to admin_editor_pages_path, notice: "Directory /#{@editor_page_directory.name} created"
    else
      render "new"
    end
  end

  def edit
  end

  def update
    if @editor_page_directory.update(editor_page_directory_params)
      redirect_to admin_editor_pages_path, notice: "Directory updated"
    else
      render "edit"
    end
  end

  def destroy
    @editor_page_directory.destroy
    redirect_to admin_editor_pages_url, notice: "Directory destroyed"
  end

  private
  def set_editor_page_directory
    @editor_page_directory = EditorPageDirectory.friendly.find(params[:id])
  end

  def editor_page_directory_params
    params.require(:editor_page_directory).permit(:name)
  end
end
