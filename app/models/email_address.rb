class EmailAddress < ApplicationRecord
  belongs_to :person, optional: true
  belongs_to :company, optional: true
  
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :belongs_to_person_or_company
  
  scope :for_person, -> { where.not(person_id: nil) }
  scope :for_company, -> { where.not(company_id: nil) }
  scope :primary, -> { where(email_type: 'primary') }
  
  private
  
  def belongs_to_person_or_company
    if person_id.blank? && company_id.blank?
      errors.add(:base, 'Email must belong to either a person or company')
    elsif person_id.present? && company_id.present?
      errors.add(:base, 'Email cannot belong to both person and company')
    end
  end
end