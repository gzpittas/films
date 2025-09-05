class PhoneNumber < ApplicationRecord
  belongs_to :person, optional: true
  belongs_to :company, optional: true
  
  validates :number, presence: true
  validate :belongs_to_person_or_company
  
  scope :for_person, -> { where.not(person_id: nil) }
  scope :for_company, -> { where.not(company_id: nil) }
  scope :office, -> { where(phone_type: 'office') }
  scope :mobile, -> { where(phone_type: 'mobile') }
  
  # Clean phone number before saving
  before_save :clean_number
  
  private
  
  def belongs_to_person_or_company
    if person_id.blank? && company_id.blank?
      errors.add(:base, 'Phone number must belong to either a person or company')
    elsif person_id.present? && company_id.present?
      errors.add(:base, 'Phone number cannot belong to both person and company')
    end
  end
  
  def clean_number
    self.number = number.gsub(/[^\d+\-\s\(\)]/, '').strip if number.present?
  end
end