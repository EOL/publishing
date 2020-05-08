class EditorPageContentsController < ApplicationController
  before_action :set_editor_page
  before_action :set_editor_page_translation
  before_action :set_editor_page_content, only: [:show, :edit, :update, :destroy, :preview]

  # GET /editor_page_contents
  # GET /editor_page_contents.json
  def index
    @editor_page_contents = EditorPageContent.all
  end

  # GET /editor_page_contents/1
  # GET /editor_page_contents/1.json
  def show
  end

  # GET /editor_page_contents/new
  def new
    @editor_page_content = EditorPageContent.new
  end

  # GET /editor_page_contents/1/edit
  def edit
  end

  # POST /editor_page_contents
  # POST /editor_page_contents.json
  def create
    @editor_page_content = EditorPageContent.new(editor_page_content_params)
    @editor_page_content.editor_page_translation = @editor_page_translation
    @editor_page_content.status = :draft

    respond_to do |format|
      if @editor_page_content.save
        format.html { redirect_to_preview }
      else
        format.html { render :new }
      end
    end
  end

  # PATCH/PUT /editor_page_contents/1
  # PATCH/PUT /editor_page_contents/1.json
  def update
    respond_to do |format|
      if @editor_page_content.update(editor_page_content_params)
        format.html { redirect_to_preview }
      else
        format.html { render :edit }
      end
    end
  end

  # DELETE /editor_page_contents/1
  # DELETE /editor_page_contents/1.json
  def destroy
    @editor_page_content.destroy
    respond_to do |format|
      format.html { redirect_to editor_page_contents_url, notice: 'Editor page content was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def preview
    render "show"
  end

  private
    def set_editor_page
      @editor_page = EditorPage.friendly.find(params[:editor_page_id])
    end

    def set_editor_page_translation
      @editor_page_translation = EditorPageTranslation.find(params[:editor_page_translation_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_editor_page_content
      @editor_page_content = EditorPageContent.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def editor_page_content_params
      params.require(:editor_page_content).permit(:title, :content)
    end

    def redirect_to_preview
      redirect_to [@editor_page, @editor_page_translation, @editor_page_content]
    end
end
