class EditorPageTranslationsController < ApplicationController
  before_action :set_editor_page_translation, only: [:show, :edit, :update, :destroy]

  # GET /editor_page_translations
  # GET /editor_page_translations.json
  def index
    @editor_page_translations = EditorPageTranslation.all
  end

  # GET /editor_page_translations/1
  # GET /editor_page_translations/1.json
  def show
  end

  # GET /editor_page_translations/new
  def new
    @editor_page_translation = EditorPageTranslation.new
  end

  # GET /editor_page_translations/1/edit
  def edit
  end

  # POST /editor_page_translations
  # POST /editor_page_translations.json
  def create
    @editor_page_translation = EditorPageTranslation.new(editor_page_translation_params)

    respond_to do |format|
      if @editor_page_translation.save
        format.html { redirect_to @editor_page_translation, notice: 'Editor page translation was successfully created.' }
        format.json { render :show, status: :created, location: @editor_page_translation }
      else
        format.html { render :new }
        format.json { render json: @editor_page_translation.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /editor_page_translations/1
  # PATCH/PUT /editor_page_translations/1.json
  def update
    respond_to do |format|
      if @editor_page_translation.update(editor_page_translation_params)
        format.html { redirect_to @editor_page_translation, notice: 'Editor page translation was successfully updated.' }
        format.json { render :show, status: :ok, location: @editor_page_translation }
      else
        format.html { render :edit }
        format.json { render json: @editor_page_translation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /editor_page_translations/1
  # DELETE /editor_page_translations/1.json
  def destroy
    @editor_page_translation.destroy
    respond_to do |format|
      format.html { redirect_to editor_page_translations_url, notice: 'Editor page translation was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_editor_page_translation
      @editor_page_translation = EditorPageTranslation.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def editor_page_translation_params
      params.require(:editor_page_translation).permit(:title, :content, :locale, :draft_id, :published_id)
    end
end
