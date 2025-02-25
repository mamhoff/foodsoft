require 'filemagic'

class DocumentsController < ApplicationController
  before_action -> { require_plugin_enabled FoodsoftDocuments }

  def index
    if params["sort"]
      sort = case params["sort"]
               when "name" then "data IS NULL DESC, name"
               when "created_at" then "created_at"
               when "name_reverse" then "data IS NULL, name DESC"
               when "created_at_reverse" then "created_at DESC"
             end
    else
      sort = "data IS NULL DESC, name"
    end

    @documents = Document.where(parent: @document).page(params[:page]).per(@per_page).order(sort)
  end

  def new
    @document = Document.new parent_id: params[:document_id]
    @document.mime = '' unless params[:type] == 'folder'
  end

  def create
    @document = Document.new name: params[:document][:name]
    @document.parent = Document.find_by_id(params[:document][:parent_id])
    data = params[:document][:data]
    if data
      @document.data = data.read
      @document.mime = FileMagic.new(FileMagic::MAGIC_MIME).buffer(@document.data)
      raise t('.not_allowed_mime', mime: @document.mime) unless allowed_mime? @document.mime
      if @document.name.empty?
        name = File.basename(data.original_filename)
        @document.name = name.gsub(/[^\w\.\-]/, '_')
      end
    end
    @document.created_by = current_user
    @document.save!
    redirect_to @document.parent || documents_path, notice: t('.notice')
  rescue => error
    redirect_to @document.parent || documents_path, alert: t('.error', error: error.message)
  end

  def destroy
    @document = Document.find(params[:id])
    if @document.created_by == current_user or current_user.role_admin?
      @document.destroy
      redirect_to documents_path, notice: t('.notice')
    else
      redirect_to documents_path, alert: t('.no_right')
    end
  rescue => error
    redirect_to documents_path, alert: t('.error', error: error.message)
  end

  def show
    @document = Document.find(params[:id])
    if @document.file?
      send_data(@document.data, filename: @document.filename, type: @document.mime)
    else
      index
      render :index
    end
  end

  def allowed_mime?(mime)
    whitelist = FoodsoftConfig[:documents_allowed_extension].split
    MIME::Types.type_for(whitelist).each do |type|
      return true if type.like? mime
    end
    false
  end
end
