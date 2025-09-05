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
    puts 'Cleared existing production, person, and company data.'

    # Read the text from the PDF file
    pdf_text = PDF::Reader.new(Rails.root.join('app', 'assets', 'pdfs', 'production_weekly.pdf')).pages.map(&:text).join(' ')
    production_entries = pdf_text.split(/(?=“)/)
    
    # Track imported counts for a final summary
    imported_productions = 0
    imported_people = 0
    imported_companies = 0
    
    # Process each entry
    production_entries.each do |entry|
      # Skip malformed or irrelevant entries
      next unless entry.include?('STATUS:') && !entry.include?('Production Weekly')
      
      # Extract the title first, as it's the most reliable marker
      title_match = entry.match(/“([^”]+)”/)
      title = title_match ? title_match[1].strip : 'Untitled'

      # Split the entry into logical sections after the title
      details_lines = entry.split("\n")
      details = details_lines.drop(1).join("\n")

      # Use regex to safely extract data from the first line after the title
      first_line_after_title = details_lines.first.strip
      production_type_match = first_line_after_title.match(/(Limited Series|Series|Feature Film)\s\/\s(.*)/i)
      if production_type_match
        production_type = production_type_match[1].strip
        network = production_type_match[2].strip.gsub(/\s\d{2}-\d{2}-\d{2}ê?/, '')
      else
        production_type = nil
        network = nil
      end

      status_match = details.match(/STATUS: (.*?) LOCATION/)
      status = status_match ? status_match[1].strip : nil

      location_match = details.match(/LOCATION: ([^\n]+)/)
      location = location_match ? location_match[1].strip : nil

      # Now, let's process the rest of the entry
      remaining_text = details

      # Extract credits and remove them from the remaining text
      credits_data = {}
      remaining_text.scan(/([A-Z\/]+): (.+?)(?=[A-Z\/]+: |\z)/m).each do |role, names|
        credits_data[role.strip] = names.strip
      end
      credits_text = credits_data.map { |role, names| "#{role}: #{names}" }.join("\n")
      remaining_text.gsub!(credits_text, '')

      # Extract companies and remove them from the remaining text
      companies_data = []
      remaining_text.scan(/([A-Z\s,.]+)(\d{4,5}[^\s,]+)\s+([^\n]+)/).each do |match|
        name, address, contact_info = match
        companies_data << {
          name: name.strip,
          address: address.strip,
          phones: contact_info.match(/\d{3}-\d{3}-\d{4}/).to_s,
          emails: contact_info.match(/[\w.-]+@[\w.-]+/).to_s,
        }
      end
      companies_text = companies_data.map { |c| "#{c[:name]} #{c[:address]} #{c[:phones]} #{c[:emails]}" }.join(' ')
      remaining_text.gsub!(companies_text, '')
      
      # The description is what's left
      description_text = remaining_text.strip
      
      # Create the production
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
      credits_data.each do |role, names|
        names.split('-').each do |name_part|
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
  end
end
