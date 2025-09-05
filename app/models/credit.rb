class Credit < ApplicationRecord
  belongs_to :production
  belongs_to :person
  belongs_to :role
end
