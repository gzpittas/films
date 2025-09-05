# app/models/person.rb
class Person < ApplicationRecord
  has_many :credits, dependent: :destroy
  has_many :productions, through: :credits
end