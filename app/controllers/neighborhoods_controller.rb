class NeighborhoodsController < ApplicationController

  before_filter :login_required
  before_filter :authorize_change, :only => [:update, :destroy]

  # GET /neighborhoods
  # GET /neighborhoods.xml
  def index
    @top_level_neighborhoods = Neighborhood.find(:all, :conditions => "parent_id is NULL").sort_by {|a| a.name}
    @neighborhoods = Neighborhood.find(:all).sort_by { |a| a.name }

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @neighborhoods }
    end
  end

  # GET /neighborhoods/1
  # GET /neighborhoods/1.xml
  def show
    @neighborhood = Neighborhood.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @neighborhood }
    end
  end

  # GET /neighborhoods/new
  # GET /neighborhoods/new.xml
  def new
    @neighborhood = Neighborhood.new
    @all_neighborhoods = Neighborhood.find(:all, :order => "parent_id, name").sort_by { |a| a.long_name }

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @neighborhood }
    end
  end

  # GET /neighborhoods/1/edit
  def edit
    @neighborhood = Neighborhood.find(params[:id])
    @all_neighborhoods = Neighborhood.find(:all, :order => "parent_id, name").sort_by { |a| a.long_name }
  end

  # POST /neighborhoods
  # POST /neighborhoods.xml
  def create
    @neighborhood = Neighborhood.new(params[:neighborhood])

    respond_to do |format|
      if @neighborhood.save
        flash[:notice] = 'Neighborhood was successfully created.'
        format.html { redirect_to(@neighborhood) }
        format.xml  { render :xml => @neighborhood, :status => :created, :location => @neighborhood }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @neighborhood.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /neighborhoods/1
  # PUT /neighborhoods/1.xml
  def update
    @neighborhood = Neighborhood.find(params[:id])

    respond_to do |format|
      if @neighborhood.update_attributes(params[:neighborhood])
        flash[:notice] = 'Neighborhood was successfully updated.'
        format.html { redirect_to(@neighborhood) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @neighborhood.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /neighborhoods/1
  # DELETE /neighborhoods/1.xml
  def destroy
    @neighborhood = Neighborhood.find(params[:id])
    @neighborhood.destroy

    respond_to do |format|
      format.html { redirect_to(neighborhoods_url) }
      format.xml  { head :ok }
    end
  end

  private

  def authorize_change
    authorized = current_person.admin?
    flash[:error] = 'Authorization required to edit neighborhood'
    redirect_to home_url unless authorized
  end
end
