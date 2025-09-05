class Person < ApplicationRecord
  has_many :credits, dependent: :destroy
  has_many :productions, through: :credits
  has_many :roles, through: :credits
  has_many :email_addresses, dependent: :destroy
  has_many :phone_numbers, dependent: :destroy
  
  validates :name, presence: true
  
  scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") if name.present? }
  scope :with_role, ->(role_name) do
    joins(credits: :role).where(roles: { name: role_name }) if role_name.present?
  end
  
  # Get primary email
  def primary_email
    email_addresses.find_by(email_type: 'primary')&.email ||
    email_addresses.first&.email
  end
  
  # Get primary phone
  def primary_phone
    phone_numbers.find_by(phone_type: 'mobile')&.number ||
    phone_numbers.first&.number
  end
end