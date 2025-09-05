class ProductionCompany < ApplicationRecord
  belongs_to :production
  belongs_to :company
  
  validates :production_id, uniqueness: { scope: :company_id }
end