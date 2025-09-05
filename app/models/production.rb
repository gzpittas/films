# app/models/production.rb
class Production < ApplicationRecord
  has_many :companies, dependent: :destroy
  has_many :credits, dependent: :destroy
  has_many :people, through: :credits
end