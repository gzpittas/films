# app/models/credit.rb
class Credit < ApplicationRecord
  belongs_to :production
  belongs_to :person
end