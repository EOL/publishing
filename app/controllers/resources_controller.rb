class ResourcesController < ApplicationController
  before_action :require_admin, except: [:index, :show, :by_abbr, :autocomplete]
  before_action :set_resource, only: [:republish, :clean_republish]

  def index
    @resources = Resource.order('updated_at DESC')
    respond_to do |fmt|
      fmt.html do
        @resources = @resources.by_page(params[:page] || 1).per(10)
      end
      fmt.json do
        @resources.includes(:partner, :dataset_licesnse)
      end
    end
  end

  def by_abbr
    @resource = Resource.find_by_abbr(params[:abbr])

    respond_to do |fmt|
      fmt.json do
        render json: {
          id: @resource.id,
          repository_id: @resource.repository_id,
          abbr: @resource.abbr,
          name: @resource.name,
          description: @resource.description,
          notes: @resource.notes,
          is_browsable: @resource.is_browsable,
          has_duplicate_nodes: @resource.has_duplicate_nodes,
          node_source_url_template: @resource.node_source_url_template,
          dataset_license_id: @resource.dataset_license_id,
          dataset_rights_holder: @resource.dataset_rights_holder,
          dataset_rights_statement: @resource.dataset_rights_statement,
          classification: @resource.classification
        }
      end
    end
  end

  def show
    @resource = Resource.find(params[:id])
  end

  def clear_publishing
    ImportLog.all_clear!
    flash[:notice] = 'All clear. You can publish, now.'
    redirect_to resources_path
  end

  def diff
    @resource.diff
    flash[:notice] = "diff for #{@resource.name} will be processed in the background. Watch this page for updates."
    redirect_to @resource
  end

  def republish
    republish_helper
  end

  def clean_republish
    @resource.update!(last_published_at: nil)
    republish_helper
  end

  def reindex
    @resource = Resource.find(params[:resource_id])
    Delayed::Job.enqueue(ReindexJob.new(@resource.id))
    flash[:notice] = "#{@resource.name} will be reindexed in the background. Watch this page for updates."
    redirect_to @resource
  end

  def fix_no_names
    @resource = Resource.find(params[:resource_id])
    Delayed::Job.enqueue(FixNoNamesJob.new(@resource.id))
    flash[:notice] = "#{@resource.name} will fix NO NAME problems in the background. Expect 1 min per 2000 nodes."
    redirect_to @resource
  end

  def autocomplete
    resources = Resource.autocomplete(params[:query])
    render json: resources.collect { |r| { name: r[:name], id: r[:id] } }
  end

  def dashboard
    @delayed_job_log = `tail -n 20 #{Rails.root.join('log', 'delayed_job.log')}`.split(/\n/)
    @import_logs = ImportLog.where("completed_at IS NULL AND failed_at IS NULL")
    @git_log = `git log | grep "^    " | grep -v "Merge branch" | head -n 20`.split(/\n/)
    @uptime = `uptime`.chomp
    @top_cpu = `ps aux | sort -nrk 3,3 | head -n 3`.split(/\n/)
    @queue_count = Delayed::Job.count
    @queue = Delayed::Job.all.limit(16)
  end

  private
  def republish_helper
    if @resource.publish_pending?
      flash[:notice] = "FAILED! #{@resource.name} ALREADY has a publish pending (which has not begun). You don't want duplicates. Watch this page for updates."
    else
      @resource.republish
      flash[:notice] = "#{@resource.name} will be processed in the background. Watch this page for updates."
    end
    redirect_to @resource
  end

  def set_resource
    @resource = Resource.find(params[:resource_id])
  end
end
