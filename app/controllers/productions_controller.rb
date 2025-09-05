# app/controllers/productions_controller.rb
class ProductionsController < ApplicationController
  before_action :set_production, only: [:show]
  
  def index
    @productions = Production.includes(:companies, :people, :credits, :roles)
    
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
    
    @productions = @productions.distinct.order(:title)
    
    # Pagination if using Kaminari
    @productions = @productions.page(params[:page]).per(20) if respond_to?(:page)
    
    respond_to do |format|
      format.html
      format.json { render json: @productions }
      format.csv { send_data export_csv, filename: "productions-#{Date.current}.csv" }
    end
  end
  
  def show
    @emails = @production.all_emails
    @phones