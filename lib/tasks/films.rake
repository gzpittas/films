# lib/tasks/import_productions.rake
# frozen_string_literal: true

namespace :import do
  desc 'Imports productions from Production Weekly PDF into the database'
  task productions: :environment do
    require 'pdf-reader'

    text_file_path = Rails.root.join('db', 'data', 'production_weekly.pdf')

    unless File.exist?(text_file_path)
      puts "Error: Production data file not found at '#{text_file_path}'"
      exit
    end

    # Seed common roles first
    puts "Seeding common roles..."
    Role.seed_common_roles!

    # Enhanced parser for Production Weekly format
    class ProductionWeeklyParser
      CompanyData = Struct.new(:name, :address, :phones, :emails, :role)
      PersonData = Struct.new(:name, :role, :emails, :phones)

      def self.extract_companies(block)
        companies = []
        lines = block.split("\n").map(&:strip).reject(&:empty?)
        
        current_company = nil
        
        lines.each_with_index do |line, i|
          # Skip title lines and credit lines
          next if line.match?(/^".*"/) || 
                  line.match?(/STATUS:|LOCATION:|PRODUCER:|DIRECTOR:|WRITER:|CAST:|LP:|PM:|PC:|DP:|1AD:|CD:|SHOWRUNNER:/)
          
          # Company name detection
          if line.match?(/^[A-Z][A-Z\s&.,-]+(?:INC\.|LLC|LTD|COMPANY|PRODUCTIONS?|FILMS?|ENTERTAINMENT|STUDIOS?|MEDIA|PICTURES|CAPITAL|GROUP|AGENCY)?\.?\s*$/) ||
             line.match?(/^[A-Z][A-Z\s&.,-]*(?:INC\.|LLC|LTD|COMPANY|PRODUCTIONS?|FILMS?|ENTERTAINMENT|STUDIOS?|MEDIA|PICTURES|CAPITAL|GROUP|AGENCY)/)
            
            # Save previous company if it has contact info
            save_company(companies, current_company) if current_company
            
            # Start new company
            current_company = {
              name: clean_company_name(line),
              address: "",
              phones: [],
              emails: [],
              role: determine_company_role(line, i)
            }
          elsif current_company
            # Extract contact information
            emails = line.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i)
            current_company[:emails].concat(emails) if emails.any?
            
            phones = line.scan(/(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/)
            phones += line.scan(/\+\d{2,3}\s\d{1,3}\s\d{3}\s\d{3}\s\d{3}/)
            current_company[:phones].concat(phones) if phones.any?
            
            # Capture address info
            if !emails.any? && !phones.any? && line.match?(/\d+.*(?:St\.|Street|Ave\.|Avenue|Blvd\.|Boulevard|Dr\.|Drive|Suite|Ste\.|Floor|Road|Rd\.)/i)
              current_company[:address] = line
            end
          end
        end
        
        # Save final company
        save_company(companies, current_company) if current_company
        
        companies
      end

      def self.save_company(companies, company_data)
        return unless company_data && company_data[:name].present?
        return unless company_data[:emails].any? || company_data[:phones].any?
        
        companies << CompanyData.new(
          company_data[:name],
          company_data[:address],
          company_data[:phones],
          company_data[:emails],
          company_data[:role]
        )
      end

      def self.clean_company_name(name)
        name.strip.gsub(/\s+/, ' ')
      end

      def self.determine_company_role(name, position)
        case name.upcase
        when /PRODUCTIONS?|PROD/
          'Production Company'
        when /STUDIOS?|PICTURES/
          'Studio'
        when /ENTERTAINMENT|MEDIA|NETWORK|DISTRIBUTION/
          'Network / Distributor'
        when /NETFLIX|HBO|APPLE|AMAZON|PRIME|PEACOCK|HALLMARK/
          'Network'
        else
          position < 3 ? 'Production Company' : 'Company'
        end
      end

      def self.extract_people(block)
        people = []
        
        # Extract different roles with regex
        roles_patterns = {
          'Director' => /DIRECTOR:\s*([^\n]+?)(?=\s+(?:LP|PM|PC|DP|1AD|CD|WRITER|CAST)|$)/,
          'Writer' => /WRITER[\/]?[A-Z]*:\s*([^\n]+?)(?=\s+(?:DIRECTOR|LP|PM|PC|DP|1AD|CD|CAST)|$)/,
          'Showrunner' => /SHOWRUNNER:\s*([^\n]+?)(?=\s+(?:DIRECTOR|LP|PM|PC|DP|1AD|CD|CAST)|$)/,
          'Line Producer' => /\bLP[\/]?[A-Z]*:\s*([^\n]+?)(?=\s+(?:PM|PC|DP|1AD|CD)|$)/,
          'Production Manager' => /\bPM:\s*([^\n]+?)(?=\s+(?:PC|DP|1AD|CD)|$)/,
          'Production Coordinator' => /\bPC:\s*([^\n]+?)(?=\s+(?:DP|1AD|CD)|$)/,
          'Director of Photography' => /\bDP:\s*([^\n]+?)(?=\s+(?:1AD|CD)|$)/,
          'First Assistant Director' => /\b1AD:\s*([^\n]+?)(?=\s+(?:CD)|$)/,
          'Casting Director' => /\bCD:\s*([^\n]+)/
        }
        
        roles_patterns.each do |role, pattern|
          match = block.match(pattern)
          if match && match[1].present?
            names = match[1].split(/\s*-\s*/).map(&:strip)
            names.each do |name|
              people << PersonData.new(name, role, [], []) if name.present?
            end
          end
        end
        
        # Extract producers
        producer_match = block.match(/PRODUCER:\s*([^\n]+?)(?=\s+(?:WRITER|DIRECTOR|SHOWRUNNER)|$)/)
        if producer_match && producer_match[1].present?
          producers = producer_match[1].split(/\s*-\s*/).map(&:strip)
          producers.each do |name|
            people << PersonData.new(name, 'Producer', [], []) if name.present?
          end
        end
        
        # Extract cast
        cast_match = block.match(/CAST:\s*([^\n]+)/)
        if cast_match && cast_match[1].present?
          cast_members = cast_match[1].split(/\s*-\s*/).map(&:strip)
          cast_members.each do |name|
            people << PersonData.new(name, 'Actor', [], []) if name.present?
          end
        end
        
        people
      end

      def self.parse_production(block)
        lines = block.split("\n").map(&:strip)
        
        # Extract title
        title_line = lines.find { |line| line.match?(/^".*"/) }
        title = nil
        production_type = nil
        network = nil
        
        if title_line
          title = title_line[/"([^"]+)"/, 1]
          remainder = title_line.sub(/"[^"]+"/, '').strip
          
          # Extract type
          type_match = remainder.match(/(Feature Film|Series|Telefilm|HBSVOD Feature|Limited Series)/i)
          production_type = type_match[1] if type_match
          
          # Extract network
          network_match = remainder.match(/\/\s*([^\/\d]+)/)
          network = network_match[1]&.strip if network_match
        end

        status = extract_field(block, /STATUS:\s*([^\n]+?)(?=\s+LOCATION:|$)/)
        location = extract_field(block, /LOCATION:\s*([^\n]+)/)
        description = extract_description(block)

        {
          title: title,
          production_type: production_type,
          network: network,
          status: status,
          location: location,
          companies: extract_companies(block),
          people: extract_people(block),
          description: description
        }
      end

      private

      def self.extract_field(text, pattern)
        match = text.match(pattern)
        match&.captures&.first&.strip
      end

      def self.extract_description(block)
        lines = block.split("\n").map(&:strip).reject(&:empty?)
        
        description_lines = []
        found_description = false
        
        lines.reverse_each do |line|
          # Skip company/contact/technical info
          if line.match?(/^[A-Z][A-Z\s&.,-]+(?:INC\.|LLC|LTD|COMPANY|PRODUCTIONS?|FILMS?|ENTERTAINMENT|STUDIOS?|MEDIA|PICTURES)/) ||
             line.match?(/PHONE:|FAX:|EMAIL:|@|STATUS:|LOCATION:|PRODUCER:|DIRECTOR:|WRITER:|CAST:|LP:|PM:|PC:|DP:|1AD:|CD:|SHOWRUNNER:/) ||
             line.match?(/^\d+[-\s]\d+[-\s]\d+/) ||
             line.match?(/^[""].*[""]/)
            break if found_description
            next
          end
          
          if line.length > 50 && line.match?(/[.!?]$/)
            description_lines.unshift(line)
            found_description = true
          elsif found_description
            description_lines.unshift(line)
          end
        end
        
        description_lines.join(' ').strip if description_lines.any?
      end
    end

    puts "Starting data import from '#{text_file_path}'..."
    start_time = Time.now
    productions_imported = 0
    companies_created = 0
    people_created = 0
    errors = []

    # Read PDF
    begin
      pdf_reader = PDF::Reader.new(text_file_path)
      file_content = pdf_reader.pages.map(&:text).join("\n")
      
      # Clean content
      file_content = file_content.gsub(/Production Weekly.*?Downloaded by.*?\n/m, '')
      file_content = file_content.gsub(/© Copyright.*?\n/, '')
      
      # Split into production blocks
      production_blocks = file_content.scan(/(^"[^"]*".*?)(?=^"|$)/m)
      
      puts "Found #{production_blocks.length} potential production entries"
    rescue => e
      puts "Error reading PDF: #{e.message}"
      exit
    end

    ActiveRecord::Base.transaction do
      production_blocks.each_with_index do |block, index|
        next if block.first.strip.empty?

        begin
          parsed_data = ProductionWeeklyParser.parse_production(block.first)
          
          if parsed_data[:title].blank?
            puts "Warning: Skipping entry #{index + 1} - no title found"
            next
          end

          # Create or find production
          production = Production.find_or_initialize_by(title: parsed_data[:title])
          
          is_new_production = production.new_record?
          productions_imported += 1 if is_new_production
          
          production.assign_attributes(
            production_type: parsed_data[:production_type],
            network: parsed_data[:network],
            status: parsed_data[:status],
            location: parsed_data[:location],
            description: parsed_data[:description]
          )
          
          production.save!
          
          puts "#{is_new_production ? 'Created' : 'Updated'}: '#{production.title}'"

          # Process companies
          parsed_data[:companies]&.each do |company_data|
            next if company_data.name.blank?
            
            company = Company.find_or_initialize_by(name: company_data.name)
            
            if company.new_record?
              company.assign_attributes(
                address: company_data.address,
                role: company_data.role
              )
              company.save!
              companies_created += 1
            end

            # Link company to production
            ProductionCompany.find_or_create_by(
              production: production,
              company: company
            )

            # Add emails
            company_data.emails&.each do |email|
              next if email.blank?
              EmailAddress.find_or_create_by(
                company: company,
                email: email.downcase
              )
            end

            # Add phones
            company_data.phones&.each do |phone|
              next if phone.blank?
              PhoneNumber.find_or_create_by(
                company: company,
                number: phone.strip
              )
            end
          end

          # Process people
          parsed_data[:people]&.each do |person_data|
            next if person_data.name.blank?
            
            person = Person.find_or_create_by(name: person_data.name)
            people_created += 1 if person.previously_new_record?
            
            # Find or create role
            role = Role.find_or_create_by(name: person_data.role)
            
            # Create credit (link person to production with role)
            Credit.find_or_create_by(
              production: production,
              person: person,
              role: role
            )
          end

        rescue ActiveRecord::RecordInvalid => e
          error_msg = "Validation failed for '#{parsed_data[:title] || 'Unknown'}': #{e.message}"
          errors << error_msg
          puts "✗ #{error_msg}"
        rescue => e
          error_msg = "Unexpected error for entry #{index + 1}: #{e.message}"
          errors << error_msg
          puts "✗ #{error_msg}"
        end
      end
    end

    end_time = Time.now
    duration = end_time - start_time
    
    puts "\n" + "="*60
    puts "IMPORT SUMMARY"
    puts "="*60
    puts "✓ Productions imported/updated: #{productions_imported}"
    puts "✓ Companies created: #{companies_created}"
    puts "✓ People created: #{people_created}"
    puts "✗ Errors: #{errors.length}"
    puts "⏱  Total time: #{format('%.2f', duration)} seconds"
    
    if errors.any?
      puts "\nErrors encountered:"
      errors.each_with_index do |error, i|
        puts "#{i + 1}. #{error}"
      end
    end
    
    puts "\n🎬 Import complete!"
    puts "📊 Database now contains:"
    puts "   - #{Production.count} productions"
    puts "   - #{Company.count} companies"  
    puts "   - #{Person.count} people"
    puts "   - #{EmailAddress.count} email addresses"
    puts "   - #{PhoneNumber.count} phone numbers"
  end
end