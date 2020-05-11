class Admin::EditorPagesController < AdminController
  before_action :set_editor_page, only: %i(show edit update destroy)

  # GET /editor_pages
  # GET /editor_pages.json
  def index
    @top_level = EditorPage.top_level
    @directories = EditorPageDirectory.all
  end

  # GET /editor_pages/1
  # GET /editor_pages/1.json
  def show
  end

  # GET /editor_pages/new
  def new
    @editor_page = EditorPage.new
  end

  # GET /editor_pages/1/edit
  def edit
  end

  # POST /editor_pages
  # POST /editor_pages.json
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

  # PATCH/PUT /editor_pages/1
  # PATCH/PUT /editor_pages/1.json
  def update
    respond_to do |format|
      if @editor_page.update(editor_page_params)
        format.html { redirect_to editor_pages_path, notice: 'Editor page was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  # DELETE /editor_pages/1
  # DELETE /editor_pages/1.json
  def destroy
    @editor_page.destroy
    respond_to do |format|
      format.html { redirect_to admin_editor_pages_url, notice: 'Editor page was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_editor_page
      @editor_page = EditorPage.friendly.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def editor_page_params
      params.require(:editor_page).permit(:name)
    end
end
