class Admin::EditorPageContentsController < AdminController
  before_action :set_editor_page
  before_action :set_editor_page_locale

  def draft
    @editor_page_content = @editor_page.draft_for_locale(@editor_page_locale) || EditorPageContent.new
  end

  def save_draft
    existing = @editor_page.draft_for_locale(@editor_page_locale)
    success = if existing
                @editor_page_content = existing
                @editor_page_content.update(editor_page_content_params)
              else
                @editor_page_content = EditorPageContent.new(editor_page_content_params)
                @editor_page_content.editor_page = @editor_page
                @editor_page_content.locale = @editor_page_locale
                @editor_page_content.status = :draft
                @editor_page_content.save
             end

    if success
      redirect_to_preview
    else
      render :draft
    end
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
    @editor_page_content = @editor_page.draft_for_locale(@editor_page_locale)
  end

  private
    def set_editor_page
      @editor_page = EditorPage.friendly.find(params[:editor_page_id])
    end

    def set_editor_page_locale
      @editor_page_locale = params.require(:editor_page_locale)
    end

    # Only allow a list of trusted parameters through.
    def editor_page_content_params
      params.require(:editor_page_content).permit(:title, :content)
    end

    def redirect_to_preview
      redirect_to admin_editor_page_preview_path(@editor_page, @editor_page_locale)
    end
end
