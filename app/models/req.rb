# == Schema Information
# Schema version: 20090216032013
#
# Table name: reqs
#
#  id              :integer(4)      not null, primary key
#  name            :string(255)     
#  description     :text            
#  estimated_hours :decimal(8, 2)   default(0.0)
#  due_date        :datetime        
#  person_id       :integer(4)      
#  created_at      :datetime        
#  updated_at      :datetime        
#  active          :boolean(1)      default(TRUE)
#  twitter         :boolean(1)      
#

class Req < ActiveRecord::Base
  include ActivityLogger
  extend PreferencesHelper 

  index do
    name
    description
  end
  
  
  has_and_belongs_to_many :categories
  belongs_to :person
  belongs_to :group
  has_many :bids, :order => 'created_at DESC', :dependent => :destroy
  has_many :exchanges, :as => :metadata

  attr_protected :person_id, :created_at, :updated_at
  attr_readonly :group_id
  validates_presence_of :name, :due_date
  after_create :notify_workers, :if => :notifications
  after_create :log_activity


  named_scope :in_neighborhood, lambda{ |neighborhood|
    {
      :joins      => "JOIN people ON people.id = reqs.person_id JOIN neighborhoods_people ON neighborhoods_people.person_id = people.id JOIN neighborhoods ON neighborhoods.id  = neighborhoods_people.neighborhood_id ",
      :select     => "DISTINCT `reqs`.*" # kill duplicates
    }
  }

  class << self


    def current_and_active(page=1, category_id=nil)
      today = DateTime.now
      if category_id
        @reqs = Category.find(category_id).reqs.paginate(:all, :page => page, :conditions => ["active = ? AND due_date >= ?", true, today], :order => 'created_at DESC')
      else
        @reqs = Req.paginate(:all, :page => page, :conditions => ["reqs.active = ? AND due_date >= ?", true, today], :order => 'created_at DESC')
end
      @reqs.delete_if { |req| req.has_approved? }
    end

  end

  def unit
    if group.nil?
      "hours"
    else
      group.unit
    end
  end

  def formatted_categories
    categories.collect{|cat| ERB::Util.html_escape(cat.long_name)}.join("<br />")
   end

  def listed_categories
    categories.collect{|cat| ERB::Util.html_escape(cat.long_name)}.join(",").briefiate(100)
  end

  def has_accepted_bid?
    a = false
    bids.each {|bid| a = true if bid.accepted_at != nil }
    return a
  end

  def has_completed?
    a = false
    bids.each {|bid| a = true if bid.completed_at != nil }
    return a
  end

  def has_commitment?
    a = false
    bids.each {|bid| a = true if bid.committed_at != nil }
    return a
  end

  def has_approved?
    a = false
    bids.each {|bid| a = true if bid.approved_at != nil }
    return a
  end

  def log_activity
    if active?
      add_activities(:item => self, :person => self.person)
    end
  end

  def perform
    actually_notify_workers
  end

  private

  def validate
    if self.categories.length > 5
      errors.add_to_base('Only 5 categories are allowed per request')
    end
  end

  def notify_workers
    Cheepnis.enqueue(self)
  end

  def actually_notify_workers
    workers = []
    # even though pseudo-reqs created by direct payments do not have associated categories, let's
    # be extra cautious and check for the active property as well
    #
    if self.active? && Req.global_prefs.can_send_email? && Req.global_prefs.email_notifications?
      self.categories.each do |category|
        workers << category.people
      end

      workers.flatten!
      workers.uniq!
      workers.each do |worker|
        if worker.active?
          TempMessage.queue(PersonMailer.create_req_notification(self, worker), nil, worker) if worker.connection_notifications?
        end
      end
    end
  end
end
