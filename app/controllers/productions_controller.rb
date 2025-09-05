class ProductionsController < ApplicationController
  # The index action will fetch all productions from the database
  # to be displayed in the index view.
  def index
    @productions = Production.all
  end

  # The show action finds a single production by its ID
  # and makes it available to the show view.
  def show
    @production = Production.find(params[:id])
  end
end
