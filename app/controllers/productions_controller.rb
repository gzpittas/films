# app/controllers/productions_controller.rb
class ProductionsController < ApplicationController
  before_action :set_production, only: [:show]
  
  def index
    @productions = Production.includes(:companies, :people, credits: :role)
    
    # Apply search filters
    @productions = @productions.by_title(params[:title]) if params[:title].present?
    @productions = @productions.by_status(params[:status]) if params[:status].present?
    @productions = @productions.by_location(params[:location]) if params[:location].present?
    @productions = @productions.by_network(params[:network]) if params[:network].present?
    @productions = @productions.by_production_type(params[:production_type]) if params[:production_type].present?
    @productions = @productions.by_company(params[:company]) if params[:company].present?
    @productions = @productions.by_person(params[:person]) if params[:person].present?
    @productions = @productions.by_role(params[:role]) if params[:role].present?
    
    # General search
    @productions = @productions.search(params[:search]) if params[:search].present?
    
    @productions = @productions.distinct.order(:title).limit(50)
    
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
    @productions = filtered_productions
    emails = []
    
    @productions.each do |production|
      emails.concat(production.all_emails)
    end
    
    respond_to do |format|
      format.text { send_data emails.uniq.join("\n"), filename: "email-list-#{Date.current}.txt" }
      format.csv do
        csv_data = generate_csv do |csv|
          csv << ['Email', 'Production', 'Company/Person', 'Type']
          @productions.each do |production|
            production.companies.includes(:email_addresses).each do |company|
              company.email_addresses.each do |email|
                csv << [email.email, production.title, company.name, 'Company']
              end
            end
            production.people.includes(:email_addresses).each do |person|
              person.email_addresses.each do |email|
                csv << [email.email, production.title, person.name, 'Person']
              end
            end
          end
        end
        send_data csv_data, filename: "detailed-email-list-#{Date.current}.csv"
      end
    end
  end
  
  def export_phones
    @productions = filtered_productions
    phones = []
    
    @productions.each do |production|
      phones.concat(production.all_phone_numbers)
    end
    
    respond_to do |format|
      format.text { send_data phones.uniq.join("\n"), filename: "phone-list-#{Date.current}.txt" }
      format.csv do
        csv_data = generate_csv do |csv|
          csv << ['Phone', 'Production', 'Company/Person', 'Type']
          @productions.each do |production|
            production.companies.includes(:phone_numbers).each do |company|
              company.phone_numbers.each do |phone|
                csv << [phone.number, production.title, company.name, 'Company']
              end
            end
            production.people.includes(:phone_numbers).each do |person|
              person.phone_numbers.each do |phone|
                csv << [phone.number, production.title, person.name, 'Person']
              end
            end
          end
        end
        send_data csv_data, filename: "detailed-phone-list-#{Date.current}.csv"
      end
    end
  end
  
  private
  
  def set_production
    @production = Production.find(params[:id])
  end
  
  def filtered_productions
    productions = Production.includes(:companies, :people)
    productions = productions.by_title(params[:title]) if params[:title].present?
    productions = productions.by_status(params[:status]) if params[:status].present?
    productions = productions.by_location(params[:location]) if params[:location].present?
    productions = productions.by_network(params[:network]) if params[:network].present?
    productions = productions.by_production_type(params[:production_type]) if params[:production_type].present?
    productions = productions.by_company(params[:company]) if params[:company].present?
    productions = productions.by_person(params[:person]) if params[:person].present?
    productions = productions.by_role(params[:role]) if params[:role].present?
    
    productions.distinct
  end
  
  def export_csv
    generate_csv do |csv|
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
  
  def generate_csv
    CSV.generate(headers: true) do |csv|
      yield csv
    end
  end
end