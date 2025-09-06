# app/controllers/productions_controller.rb
class ProductionsController < ApplicationController
  before_action :set_production, only: [:show]
  before_action :set_filtered_productions, only: [:index, :export_emails, :export_phones]

  def index
    @productions = @productions.distinct.order(:title)

    respond_to do |format|
      format.html
      format.json { render json: @productions }
      format.csv { send_data export_csv, filename: "productions-#{Date.current}.csv" }
    end
  end

  def show
    @emails = @production.all_emails
    @phones = @production.all_phone_numbers
  end

  def export_emails
    send_data export_contacts(:emails, 'email'), filename: "email-list-#{Date.current}.csv"
  end

  def export_phones
    send_data export_contacts(:phones, 'phone'), filename: "phone-list-#{Date.current}.csv"
  end

  private

  def set_production
    @production = Production.find(params[:id])
  end

  # Refactored to a single method to apply all filters
  def set_filtered_productions
    @productions = Production.all.includes(:companies, :people, credits: :role)

    # Use a hash to map filter parameters to scopes, making it dynamic
    filter_scopes = {
      title: :by_title, status: :by_status, location: :by_location,
      network: :by_network, production_type: :by_production_type,
      company: :by_company, person: :by_person, role: :by_role
    }

    filter_scopes.each do |param_key, scope_name|
      @productions = @productions.send(scope_name, params[param_key]) if params[param_key].present?
    end

    @productions = @productions.search(params[:search]) if params[:search].present?
  end

  # Generic method to handle contact exports (emails and phones)
  def export_contacts(contact_type, column_name)
    CSV.generate(headers: true) do |csv|
      csv << [column_name.capitalize, 'Production', 'Company/Person', 'Type']
      @productions.each do |production|
        # Use metaprogramming to call the correct method and get contacts
        contacts = production.send("all_#{contact_type}")
        next if contacts.blank?

        # Group contacts by company and person
        production.companies.includes(contact_type).each do |company|
          company.send(contact_type).each do |contact|
            csv << [contact.send(column_name), production.title, company.name, 'Company']
          end
        end

        production.people.includes(contact_type).each do |person|
          person.send(contact_type).each do |contact|
            csv << [contact.send(column_name), production.title, person.name, 'Person']
          end
        end
      end
    end
  end

  def export_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'Title', 'Type', 'Network', 'Status', 'Location',
        'Companies', 'People', 'Emails', 'Phones', 'Description'
      ]
      
      @productions.each do |production|
        csv << [
          production.title,
          production.production_type,
          production.network,
          production.status,
          production.location,
          production.companies.pluck(:name).join('; '),
          production.people.pluck(:name).join('; '),
          production.all_emails.join('; '),
          production.all_phone_numbers.join('; '),
          production.description
        ]
      end
    end
  end
end