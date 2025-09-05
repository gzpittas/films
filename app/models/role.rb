class Role < ApplicationRecord
  has_many :credits, dependent: :destroy
  has_many :people, through: :credits
  has_many :productions, through: :credits
  
  validates :name, presence: true, uniqueness: true
  
  # Create common roles if they don't exist
  COMMON_ROLES = [
    'Director', 'Producer', 'Executive Producer', 'Writer', 'Showrunner',
    'Line Producer', 'Production Manager', 'Production Coordinator',
    'Director of Photography', 'First Assistant Director', 'Casting Director',
    'Actor', 'Actress', 'UPM'
  ].freeze
  
  def self.seed_common_roles!
    COMMON_ROLES.each do |role_name|
      find_or_create_by(name: role_name)
    end
  end
end