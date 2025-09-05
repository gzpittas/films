class Role < ApplicationRecord
  has_many :credits, dependent: :destroy
  has_many :people, through: :credits
end
