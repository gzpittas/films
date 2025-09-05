require 'pdf-reader'

namespace :films do
  desc 'Processes the weekly production PDF and populates the database'
  task process_weekly_pdf: :environment do
    pdf_path = Rails.root.join('app', 'assets', 'pdfs', 'production_weekly.pdf')

    unless File.exist?(pdf_path)
      puts "Error: PDF file not found at #{pdf_path}"
      puts "Please check the path and make sure the file exists."
      return
    end

    puts "Processing PDF file at: #{pdf_path}"
    puts "Cleared existing production, person, and company data."

    Production.destroy_all
    Person.destroy_all
    Company.destroy_all

    reader = PDF::Reader.new(pdf_path)
    full_text = reader.pages.map(&:text).join("\n")

    # This regex now correctly identifies and splits each production entry.
    # It uses a positive lookahead to split *before* each new title.
    production_entries = full_text.split(/(?=“[^”]+?”)/m)
    
    production_entries.each do |entry|
      # Skip if the entry is empty or just header/footer text
      next if entry.strip.empty? || entry.include?('Production Weekly')

      # Use more specific regexes to pull out the details from each entry.
      title_match = entry.match(/“([^”]+)”\s+(.*)/)
      next unless title_match
      
      title_str, type_network_str = title_match[1], title_match[2]
      
      status_match = entry.match(/STATUS:\s*(.*?)(?=\n|$)/)
      status = status_match ? status_match[1].strip : nil
      
      location_match = entry.match(/LOCATION:\s*(.*?)(?=\n|$)/)
      location = location_match ? location_match[1].strip : nil

      # The description is the text between the LOCATION and the first credit header
      description_match = entry.match(/LOCATION:.*?[\r\n]+(.*?)(?=\n[A-Z\/]+:|\Z)/m)
      description = description_match ? description_match[1].strip : nil
      
      production_type, network = type_network_str.strip.split(/\s+\/\s+/, 2)

      begin
        production = Production.create!(
          title: title_str.strip,
          production_type: production_type&.strip,
          network: network&.strip,
          status: status,
          location: location,
          description: description
        )
      rescue ActiveRecord::RecordInvalid => e
        puts "Error creating production for '#{title_str}': #{e.message}"
        next
      end

      # Process credits by scanning for all credit headers
      credit_regex = /(PRODUCER|WRITER\/PRODUCER|WRITER|DIRECTOR|LP|PM|PC|DP|1AD|CD):\s*(.*?)(?=\n[A-Z\/]+:|\Z)/m
      
      entry.scan(credit_regex) do |match|
        role_name = match[0].strip
        names_str = match[1].strip.split(/, | - /).map(&:strip).reject(&:empty?)

        names_str.each do |name|
          person = Person.find_or_create_by!(name: name)
          production.credits.create!(person: person, role: role_name)
        end
      end

      # Process company information using a more flexible regex
      company_regex = /([A-Z\s,]+)\n\s*([\w\s.,]+)\n\s*([\d\(\)\s\-\/]+\s+[\w@.\-\/]+)/m
      entry.scan(company_regex).each do |match|
        name, address, contact_info = match
        
        production.companies.create!(
          name: name.strip,
          address: address.strip,
          phones: contact_info.split(/\s+/)&.first,
          emails: contact_info.split(/\s+/)&.last,
          role: "Company"
        )
      end
    end

    puts "Successfully imported #{Production.count} productions."
    puts "Successfully imported #{Person.count} unique people."
    puts "Successfully imported #{Company.count} companies."
  end
end
