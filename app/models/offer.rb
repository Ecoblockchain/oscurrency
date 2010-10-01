class Offer < ActiveRecord::Base
  include ActivityLogger
  extend PreferencesHelper 

  index do 
    name
    description
  end

  has_and_belongs_to_many :categories
  has_many :exchanges, :as => :metadata
  belongs_to :person
  belongs_to :group
  attr_protected :person_id, :created_at, :updated_at
  attr_readonly :group_id
  validates_presence_of :name, :expiration_date
  after_create :notify_workers, :if => :notifications
  after_create :log_activity

  named_scope :in_neighborhood, lambda{ |neighborhood|
    {
      :joins      => "JOIN people ON people.id = offers.person_id JOIN neighborhoods_people ON neighborhoods_people.person_id = people.id JOIN neighborhoods ON neighborhoods.id  = neighborhoods_people.neighborhood_id ",
      :select     => "DISTINCT `offers`.*" # kill duplicates
    }
  }

  class << self

    def current(page=1, category_id=nil)
      today = DateTime.now
      if category_id
        Category.find(category_id).offers.paginate(:all, :page => page, :conditions => ["available_count > ? AND expiration_date >= ?", 0, today], :order => 'created_at DESC')
      else
        Offer.paginate(:all, :page => page, :conditions => ["available_count > ? AND expiration_date >= ?", 0, today], :order => 'created_at DESC')
      end
    end
  end

  def can_destroy?
    self.exchanges.length == 0
  end

  def log_activity
    add_activities(:item => self, :person => self.person)
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

  def perform
    actually_notify_workers
  end

  private

  def validate
    if self.categories.length > 5
      errors.add_to_base('Only 5 categories are allowed per offer')
    end

    unless self.group.nil?
      unless self.group.adhoc_currency?
        errors.add(:group_id, "does not have its own currency")
      end
      unless person.groups.include?(self.group)
        errors.add(:group_id, "does not include you as a member")
      end
    end
  end

  def notify_workers
    Cheepnis.enqueue(self)
  end

  def actually_notify_workers
    workers = []
    # even though pseudo-offers created by direct payments do not have associated categories, let's
    # be extra cautious and check for the active property as well
    #
    if self.active? && Offer.global_prefs.can_send_email? && Offer.global_prefs.email_notifications?
      self.categories.each do |category|
        workers << category.people
      end

      workers.flatten!
      workers.uniq!
      workers.each do |worker|
        if worker.active?
          TempMessage.queue(PersonMailer.create_offer_notification(self, worker), nil, worker) if worker.connection_notifications?
        end
      end
    end
  end
end
 
 
