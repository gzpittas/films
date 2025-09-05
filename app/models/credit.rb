class Credit < ApplicationRecord
  belongs_to :production
  belongs_to :person
  belongs_to :role
  
  validates :production_id, uniqueness: { scope: [:person_id, :role_id] }
end