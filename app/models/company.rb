class Company < ApplicationRecord
  has_many :production_companies, dependent: :destroy
  has_many :productions, through: :production_companies
  has_many :email_addresses, dependent: :destroy
  has_many :phone_numbers, dependent: :destroy
  
  validates :name, presence: true
  
  scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") if name.present? }
  scope :by_role, ->(role) { where("role ILIKE ?", "%#{role}%") if role.present? }
  
  # Get primary email
  def primary_email
    email_addresses.find_by(email_type: 'primary')&.email ||
    email_addresses.first&.email
  end
  
  # Get primary phone
  def primary_phone
    phone_numbers.find_by(phone_type: 'office')&.number ||
    phone_numbers.first&.number
  end
end