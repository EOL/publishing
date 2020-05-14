class Admin::EditorPageContentsController < AdminController
  before_action :set_editor_page
  before_action :set_editor_page_locale

  def draft
    existing = @editor_page.draft_or_stub_for_locale(@editor_page_locale)

    if existing
      @editor_page_content = existing
    else
      attrs = { 
        title: @editor_page.name,
        status: :stub,
        locale: @editor_page_locale,
        editor_page: @editor_page
      }

      if @editor_page_locale != I18n.default_locale
        default_locale_draft = @editor_page.draft_for_locale(I18n.default_locale)

        if default_locale_draft
          attrs[:content] = default_locale_draft.content
          attrs[:title] = default_locale_draft.title if default_locale_draft.title.present?
        end
      end

      @editor_page_content = EditorPageContent.create!(attrs)
    end
  end

  def save_draft
    @editor_page_content = @editor_page.find_draft_or_stub_for_locale(@editor_page_locale)
    @editor_page_content.update(editor_page_content_params.merge(status: :draft))
    render :draft
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
    @editor_page_content = @editor_page.find_draft_for_locale(@editor_page_locale)
  end

  def publish
    publish_current_draft
  end

  def unpublish
    @editor_page.find_published_for_locale(@editor_page_locale).destroy!
    redirect_to admin_editor_pages_path, notice: "#{@editor_page.name} -- #{@editor_page_locale} successfully unpublished"
  end

  def upload_image
    @editor_page_content = @editor_page.draft_or_stub_for_locale(@editor_page_locale)
    @editor_page_content.images.attach(params[:image])
    render json: { url: url_for(@editor_page_content.images.last) }
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

    def publish_current_draft
      draft = @editor_page.find_draft_for_locale(@editor_page_locale)
      old_published = @editor_page.published_for_locale(@editor_page_locale)

      EditorPageContent.transaction do
        if old_published
          old_published.destroy!
        end

        new_published = draft.dup
        new_published.status = :published
        new_published.save! 
      end

      flash[:notice] = "Draft published"
      redirect_to admin_editor_pages_path
    end
end
