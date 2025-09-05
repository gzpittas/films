class Company < ApplicationRecord
  belongs_to :production, optional: true
end
