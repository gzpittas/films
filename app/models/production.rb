class Production < ApplicationRecord
  has_many :credits, dependent: :destroy
  has_many :people, through: :credits
  has_many :production_companies, dependent: :destroy
  has_many :companies, through: :production_companies

  validates :title, presence: true

  # Search scopes
  scope :by_title, ->(title) { where("LOWER(title) LIKE LOWER(?)", "%#{title}%") if title.present? }
  scope :by_status, ->(status) { where("LOWER(status) LIKE LOWER(?)", "%#{status}%") if status.present? }
  scope :by_location, ->(location) { where("LOWER(location) LIKE LOWER(?)", "%#{location}%") if location.present? }
  scope :by_network, ->(network) { where("LOWER(network) LIKE LOWER(?)", "%#{network}%") if network.present? }
  scope :by_production_type, ->(type) { where("LOWER(production_type) LIKE LOWER(?)", "%#{type}%") if type.present? }

  # Search by person name and role
  scope :by_person, ->(person_name) do
    joins(:people).where("LOWER(people.name) LIKE LOWER(?)", "%#{person_name}%") if person_name.present?
  end

  scope :by_role, ->(role_name) do
    joins(credits: :role).where("LOWER(roles.name) LIKE LOWER(?)", "%#{role_name}%") if role_name.present?
  end

  scope :by_company, ->(company_name) do
    joins(:companies).where("LOWER(companies.name) LIKE LOWER(?)", "%#{company_name}%") if company_name.present?
  end

  # Refactored to use flat_map for a single, concise line
  def all_emails
    [companies.flat_map(&:email_addresses), people.flat_map(&:email_addresses)].flatten.uniq.compact
  end

  def all_phone_numbers
    [companies.flat_map(&:phone_numbers), people.flat_map(&:phone_numbers)].flatten.uniq.compact
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
      "LOWER(title) LIKE LOWER(?) OR LOWER(status) LIKE LOWER(?) OR LOWER(location) LIKE LOWER(?) OR LOWER(network) LIKE LOWER(?) OR LOWER(description) LIKE LOWER(?)",
      "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
    )
  end
end
