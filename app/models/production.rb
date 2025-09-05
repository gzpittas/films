class Production < ApplicationRecord
  has_many :credits, dependent: :destroy
  has_many :people, through: :credits
  has_many :production_companies, dependent: :destroy
  has_many :companies, through: :production_companies
  
  validates :title, presence: true
  
  # Search scopes
  scope :by_title, ->(title) { where("title ILIKE ?", "%#{title}%") if title.present? }
  scope :by_status, ->(status) { where("status ILIKE ?", "%#{status}%") if status.present? }
  scope :by_location, ->(location) { where("location ILIKE ?", "%#{location}%") if location.present? }
  scope :by_network, ->(network) { where("network ILIKE ?", "%#{network}%") if network.present? }
  scope :by_production_type, ->(type) { where("production_type ILIKE ?", "%#{type}%") if type.present? }
  
  # Search by person name and role
  scope :by_person, ->(person_name) do
    joins(:people).where("people.name ILIKE ?", "%#{person_name}%") if person_name.present?
  end
  
  scope :by_role, ->(role_name) do
    joins(credits: :role).where("roles.name ILIKE ?", "%#{role_name}%") if role_name.present?
  end
  
  scope :by_company, ->(company_name) do
    joins(:companies).where("companies.name ILIKE ?", "%#{company_name}%") if company_name.present?
  end
  
  # Get all email addresses for this production
  def all_emails
    emails = []
    # Get emails from companies
    emails += companies.joins(:email_addresses).pluck('email_addresses.email')
    # Get emails from people
    emails += people.joins(:email_addresses).pluck('email_addresses.email')
    emails.uniq.compact
  end
  
  # Get all phone numbers for this production
  def all_phone_numbers
    phones = []
    # Get phones from companies
    phones += companies.joins(:phone_numbers).pluck('phone_numbers.number')
    # Get phones from people
    phones += people.joins(:phone_numbers).pluck('phone_numbers.number')
    phones.uniq.compact
  end
  
  # Get people by role
  def people_with_role(role_name)
    people.joins(credits: :role).where(roles: { name: role_name })
  end
  
  # Convenience methods for common roles
  def directors
    people_with_role('Director')
  end
  
  def producers
    people_with_role('Producer')
  end
  
  def writers
    people_with_role('Writer')
  end
  
  def casting_directors
    people_with_role('Casting Director')
  end
  
  def self.search(query)
    return all if query.blank?
    
    where(
      "title ILIKE ? OR status ILIKE ? OR location ILIKE ? OR network ILIKE ? OR description ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
    )
  end
end