# Version 6.0

# frozen_string_literal: true

require 'pdf-reader'
require 'byebug'

namespace :films do
  desc 'Processes weekly PDF and populates the database'
  task process_weekly_pdf: :environment do
    puts "Processing PDF file at: #{Rails.root.join('app', 'assets', 'pdfs', 'production_weekly.pdf')}"

    # Clear existing data to prevent duplicates
    Production.destroy_all
    Person.destroy_all
    Company.destroy_all
    Role.destroy_all
    puts 'Cleared existing production, person, company, and role data.'

    # Read the text from the PDF file
    pdf_text = PDF::Reader.new(Rails.root.join('app', 'assets', 'pdfs', 'production_weekly.pdf')).pages.map(&:text).join(' ')
    production_entries = pdf_text.split(/(?=“)/)
    
    # Track imported counts for a final summary
    imported_productions = 0
    imported_people = 0
    imported_companies = 0
    imported_roles = 0
    
    # Process each entry
    production_entries.each do |entry|
      # Skip malformed or irrelevant entries
      next unless entry.include?('STATUS:') && !entry.include?('Production Weekly')

      # Use a robust regex to find and remove the companies first
      companies_data = []
      companies_regex = /([A-Z\s,.]+)\s(\d{4,5}[^\s,]+)\s([^\n]+)/
      entry.scan(companies_regex).each do |match|
        name, address, contact_info = match
        companies_data << {
          name: name.strip,
          address: address.strip,
          phones: contact_info.match(/\d{3}-\d{3}-\d{4}/).to_s,
          emails: contact_info.match(/[\w.-]+@[\w.-]+/).to_s,
        }
      end
      
      # Use a robust regex to find and remove credits
      credits_data = {}
      credits_regex = /([A-Z\/]+): (.+?)(?=[A-Z\/]+: |\z)/m
      entry.scan(credits_regex).each do |role, names|
        credits_data[role.strip] = names.strip
      end
      
      # The remaining text will contain the core details and description
      remaining_text = entry.dup
      
      # Remove companies and credits text from the entry
      companies_text = companies_data.map { |c| "#{c[:name]} #{c[:address]} #{c[:phones]} #{c[:emails]}" }.join(' ')
      credits_text = credits_data.map { |role, names| "#{role}: #{names}" }.join("\n")
      
      # Now, we extract core details from the entry without the credits and companies
      remaining_text.gsub!(companies_text, '')
      remaining_text.gsub!(credits_text, '')
      
      # Extract the title first, as it's the most reliable marker
      title_match = remaining_text.match(/“([^”]+)”/)
      title = title_match ? title_match[1].strip : 'Untitled'

      # The description is what's left after removing all structured data
      description_text = remaining_text.gsub(title_match[0], '').strip
      
      # Extract everything else from the remaining text
      production_type_match = remaining_text.match(/(Limited Series|Series|Feature Film)\s\/\s(.*)/i)
      production_type = production_type_match ? production_type_match[1].strip : nil
      network = production_type_match ? production_type_match[2].strip.gsub(/\s\d{2}-\d{2}-\d{2}ê?/, '') : nil
      
      status_match = remaining_text.match(/STATUS: (.*?) LOCATION/)
      status = status_match ? status_match[1].strip : nil

      location_match = remaining_text.match(/LOCATION: ([^\n]+)/)
      location = location_match ? location_match[1].strip : nil
      
      # Create the production record
      production = Production.create!(
        title: title,
        production_type: production_type,
        network: network,
        status: status,
        location: location,
        description: description_text
      )
      imported_productions += 1
      
      # Process companies
      companies_data.each do |company_data|
        Company.create!(
          name: company_data[:name],
          address: company_data[:address],
          phones: company_data[:phones],
          emails: company_data[:emails],
          production: production
        )
        imported_companies += 1
      end

      # Process credits
      credits_data.each do |role_name, names|
        # Find or create the role record
        role = Role.find_or_create_by!(name: role_name.strip)
        imported_roles += 1 if role.persisted?

        # Process each person and create a credit record
        names.split(/ - | and /).each do |name_part|
          name = name_part.strip
          if name.present?
            person = Person.find_or_create_by!(name: name)
            production.credits.create!(person: person, role: role)
            imported_people += 1
          end
        end
      end
    end
    
    # Print a summary of the import
    puts "Successfully imported #{imported_productions} productions."
    puts "Successfully imported #{imported_people} unique people."
    puts "Successfully imported #{imported_companies} companies."
    puts "Successfully imported #{imported_roles} unique roles."
  end
end
