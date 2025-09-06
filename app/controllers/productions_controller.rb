# app/controllers/productions_controller.rb
class ProductionsController < ApplicationController
  def index
    @productions = Production.includes(:companies, :contacts)
    
    # Apply search filters
    @productions = @productions.by_title(params[:title]) if params[:title].present?
    @productions = @productions.by_status(params[:status]) if params[:status].present?
    @productions = @productions.by_director(params[:director]) if params[:director].present?
    @productions = @productions.by_location(params[:location]) if params[:location].present?
    
    # Company search
    if params[:company].present?
      @productions = @productions.joins(:companies)
                                 .where("companies.name ILIKE ?", "%#{params[:company]}%")
    end
    
    # Producer search (search in contacts)
    if params[:producer].present?
      @productions = @productions.joins(:contacts)
                                 .where("contacts.name ILIKE ? AND contacts.role = ?", 
                                        "%#{params[:producer]}%", "Producer")
    end
    
    @productions = @productions.distinct.page(params[:page])
    
    respond_to do |format|
      format.html
      format.json
      format.csv { send_data export_csv, filename: "productions-#{Date.current}.csv" }
    end
  end
  
  def show
    @production = Production.find(params[:id])
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
        csv_data = CSV.generate do |csv|
          csv << ['Email', 'Production', 'Company/Contact', 'Type']
          @productions.each do |production|
            production.companies.includes(:email_addresses).each do |company|
              company.email_addresses.each do |email|
                csv << [email.email, production.title, company.name, 'Company']
              end
            end
            production.contacts.includes(:email_addresses).each do |contact|
              contact.email_addresses.each do |email|
                csv << [email.email, production.title, contact.name, 'Contact']
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
        csv_data = CSV.generate do |csv|
          csv << ['Phone', 'Production', 'Company/Contact', 'Type']
          @productions.each do |production|
            production.companies.includes(:phone_numbers).each do |company|
              company.phone_numbers.each do |phone|
                csv << [phone.number, production.title, company.name, 'Company']
              end
            end
            production.contacts.includes(:phone_numbers).each do |contact|
              contact.phone_numbers.each do |phone|
                csv << [phone.number, production.title, contact.name, 'Contact']
              end
            end
          end
        end
        send_data csv_data, filename: "detailed-phone-list-#{Date.current}.csv"
      end
    end
  end
  
  private
  
  def filtered_productions
    productions = Production.includes(:companies, :contacts)
    productions = productions.by_title(params[:title]) if params[:title].present?
    productions = productions.by_status(params[:status]) if params[:status].present?
    productions = productions.by_director(params[:director]) if params[:director].present?
    productions = productions.by_location(params[:location]) if params[:location].present?
    
    if params[:company].present?
      productions = productions.joins(:companies)
                              .where("companies.name ILIKE ?", "%#{params[:company]}%")
    end
    
    if params[:producer].present?
      productions = productions.joins(:contacts)
                              .where("contacts.name ILIKE ? AND contacts.role = ?", 
                                     "%#{params[:producer]}%", "Producer")
    end
    
    productions.distinct
  end
  
  def export_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'Title', 'Type', 'Network', 'Status', 'Location', 
        'Director', 'Line Producer', 'UPM', 'Companies', 
        'Emails', 'Phones', 'Description'
      ]
      
      @productions.each do |production|
        csv << [
          production.title,
          production.film_type,
          production.network,
          production.status,
          production.location,
          production.director,
          production.line_producer,
          production.upm,
          production.companies.pluck(:name).join('; '),
          production.all_emails.join('; '),
          production.all_phone_numbers.join('; '),
          production.description
        ]
      end
    end
  end
end

# app/controllers/companies_controller.rb
class CompaniesController < ApplicationController
  def index
    @companies = Company.includes(:productions, :email_addresses, :phone_numbers)
    @companies = @companies.by_name(params[:name]) if params[:name].present?
    @companies = @companies.by_role(params[:role]) if params[:role].present?
    @companies = @companies.page(params[:page])
  end
  
  def show
    @company = Company.find(params[:id])
  end
end

# config/routes.rb
Rails.application.routes.draw do
  root 'productions#index'
  
  resources :productions do
    collection do
      get :export_emails
      get :export_phones
    end
  end
  
  resources :companies
  resources :contacts
  
  # API routes for search
  namespace :api do
    namespace :v1 do
      resources :productions, only: [:index, :show]
      resources :companies, only: [:index, :show]
    end
  end
end