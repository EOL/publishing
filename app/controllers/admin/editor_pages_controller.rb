class Admin::EditorPagesController < AdminController
  before_action :set_directory
  before_action :set_editor_page, only: %i(show edit update destroy)

  def index
    @top_level = EditorPage.top_level
    @directories = EditorPageDirectory.all
  end

  def new
    @editor_page = EditorPage.new(editor_page_directory: @directory)
  end

  def edit
  end

  def create
    @editor_page = EditorPage.new(editor_page_params)

    respond_to do |format|
      if @editor_page.save
        format.html { redirect_to admin_editor_pages_path, notice: 'Editor page was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  def update
    respond_to do |format|
      if @editor_page.update(editor_page_params)
        format.html { redirect_to admin_editor_pages_path, notice: 'Editor page was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  def destroy
    @editor_page.destroy
    respond_to do |format|
      format.html { redirect_to admin_editor_pages_url, notice: 'Editor page was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    def set_editor_page
      @editor_page = if @directory
                       @directory.editor_pages.friendly.find(params[:id])
                     else
                       EditorPage.friendly.find(params[:id])
                     end
    end

    def set_directory
      @directory = params[:editor_page_directory_id].present? ? 
        EditorPageDirectory.friendly.find(params[:editor_page_directory_id]) :
        nil
    end

    def editor_page_params
      params.require(:editor_page).permit(:name, :slug, :editor_page_directory_id)
    end
end
