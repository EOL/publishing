class ResourcesController < ApplicationController
  before_action :require_admin, except: [:index, :show, :autocomplete]

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

  def show
    @resource = Resource.find(params[:id])
  end

  def sync
    if (info = ImportLog.already_running?)
      flash[:alert] = info
    else
      Publishing.delay(queue: 'harvest').sync
      flash[:notice] = "Resources will be checked against the repository."
    end
    redirect_to resources_path
  end

  def sync_all_terms
    if (info = ImportLog.already_running?)
      flash[:alert] = info
    else
      Publishing.delay(queue: 'harvest').sync(20.years.ago)
      flash[:notice] = "All terms from the harvesting layer will be published here."
    end
    redirect_to resources_path
  end

  def clear_publishing
    ImportLog.all_clear!
    flash[:notice] = "All clear. You can sync, now."
    redirect_to resources_path
  end

  def republish
    @resource = Resource.find(params[:resource_id])
    Delayed::Job.enqueue(RepublishJob.new(@resource.id))
    flash[:notice] = "#{@resource.name} will be published in the background. Watch this page for updates."
    redirect_to @resource
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
    @queue = Delayed::Job.all.limit(5)
  end
end
