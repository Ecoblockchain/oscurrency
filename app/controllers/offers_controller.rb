class OffersController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  before_filter :correct_person_required, :only => [:edit, :update, :destroy]

  def index
    @offers = Offer.current(params[:page])

    respond_to do |format|
      format.html # index.html.erb
      format.xml { render :xml => @offers }
    end
  end

  def show
    @offer = Offer.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @offer }
    end
  end

  def new
    @offer = Offer.new
    @all_categories = Category.find(:all, :order => "parent_id, name").sort_by { |a| a.long_name }
  end

  def create
    @offer = Offer.new(params[:offer])
    ##TODO: move this to the model, a before_create method?
    @offer.available_count = @offer.total_available
    @offer.person_id = current_person.id

    respond_to do |format|
      if @offer.save
        flash[:notice] = 'Offer was successfully created.'
        format.html { redirect_to(@offer) }
        format.xml  { render :xml => @offer, :status => :created, :location => @offer }
      else
        @all_categories = Category.find(:all, :order => "parent_id, name").sort_by { |a| a.long_name }
        format.html { render :action => "new" }
        format.xml  { render :xml => @offer.errors, :status => :unprocessable_entity }
      end
    end
  end

  def edit
    @offer = Offer.find(params[:id])
    @all_categories = Category.find(:all, :order => "parent_id, name").sort_by { |a| a.long_name }
  end

  def update
    @offer = Offer.find(params[:id])

    respond_to do |format|
      if @offer.update_attributes(params[:offer])
        flash[:notice] = 'Offer was successfully updated.'
        format.html { redirect_to(@offer) }
        format.xml  { head :ok }
      else
        @all_categories = Category.find(:all, :order => "parent_id, name").sort_by { |a| a.long_name }
        format.html { render :action => "edit" }
        format.xml  { render :xml => @offer.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @offer = Offer.find(params[:id])
    if @offer.can_destroy?
      @offer.destroy
    else
      flash[:error] = 'This offer cannot be deleted as it has been accepted'
    end

    respond_to do |format|
      format.html { redirect_to(offers_url) }
      format.xml  { head :ok }
    end
  end

private

  def correct_person_required
    redirect_to home_url unless ( current_person.admin? or Offer.find(params[:id]).person == current_person )
  end
end
