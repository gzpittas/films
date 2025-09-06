# lib/tasks/import_fixed.rake
# frozen_string_literal: true

namespace :import do
  desc 'Fixed import with correct quote detection'
  task fixed_productions: :environment do
    require 'pdf-reader'

    text_file_path = Rails.root.join('db', 'data', 'production_weekly.pdf')

    unless File.exist?(text_file_path)
      puts "Error: Production data file not found at '#{text_file_path}'"
      exit
    end

    # Seed common roles first
    puts "Seeding common roles..."
    Role.seed_common_roles!

    # Fixed parser that correctly identifies titles
    class FixedPDFParser
      def self.parse_pdf_content(file_content)
        lines = file_content.split("\n").map(&:strip).reject(&:empty?)
        
        productions = []
        current_production = nil
        i = 0
        
        while i < lines.length
          line = lines[i]
          
          # Debug: check title line detection
          if line.include?('"')
            puts "Checking line: #{line[0..80]}..."
            puts "  Starts with quote: #{line.strip.start_with?('"')}"
            puts "  Contains production type: #{line.match?(/(Feature Film|Series|Telefilm|Limited Series|HBSVOD Feature)/i)}"
            puts "  Is title line: #{is_title_line?(line)}"
          end
          
          # Look for production titles - lines that start with quotes and contain "Feature Film", "Series", etc.
          if is_title_line?(line)
            # Save previous production if exists
            productions << current_production if current_production && current_production[:title].present?
            
            # Start new production
            current_production = parse_title_line(line)
            current_production[:companies] = []
            current_production[:people] = []
            current_production[:content_lines] = []
            
            puts "Found production title: '#{current_production[:title]}'"
            
          elsif current_production
            # Add line to current production's content for further processing
            current_production[:content_lines] << line
            
            # Parse specific information from each line
            parse_production_line(line, current_production)
          end
          
          i += 1
        end
        
        # Don't forget the last production
        productions << current_production if current_production && current_production[:title].present?
        
        # Process descriptions for each production
        productions.each do |prod|
          prod[:description] = extract_description(prod[:content_lines])
        end
        
        productions
      end
      
      def self.is_title_line?(line)
        # A title line should:
        # 1. Start with a quote
        # 2. End with a quote followed by production type keywords
        # 3. Not be part of a description (not too long and not containing common description words)
        
        return false unless line.start_with?('"')
        return false if line.length > 100 # Too long to be a title line
        return false if line.match?(/was.*years.*old|trying to|perfect|playground/) # Description keywords
        
        # Should contain production type keywords after the closing quote
        line.match?(/"\s*(Feature Film|Series|Telefilm|Limited Series|HBSVOD Feature)/i)
      end
      
      def self.parse_title_line(line)
        # Extract title from quotes - handle concatenated titles
        title_match = line.match(/^"([^"]+)"/)
        title = title_match[1] if title_match
        
        if title
          # Fix concatenated title by adding spaces
          title = fix_concatenated_text(title)
        end
        
        # Extract production type and network from remainder
        remainder = line.sub(/^"[^"]+"/, '').strip
        
        production_type = nil
        network = nil
        
        # Extract type
        type_match = remainder.match(/(Feature Film|Series|Telefilm|Limited Series|HBSVOD Feature)/i)
        production_type = type_match[1] if type_match
        
        # Extract network (after /)
        network_match = remainder.match(/\/\s*([^\n]+)/)
        network = network_match[1].strip if network_match
        
        {
          title: title,
          production_type: production_type,
          network: network,
          status: nil,
          location: nil,
          description: nil
        }
      end
      
      def self.fix_concatenated_text(text)
        return text if text.blank?
        
        # Add spaces before capital letters that follow lowercase letters or numbers
        fixed_text = text.gsub(/([a-z\d])([A-Z])/, '\1 \2')
        
        # Handle specific patterns
        fixed_text = fixed_text.gsub(/(\d)(MILES|DAYS|YEARS)/i, '\1 \2')
        
        # Clean up multiple spaces
        fixed_text.squeeze(' ').strip
      end
      
      def self.parse_production_line(line, production)
        # Status and Location
        if line.match?(/STATUS:/)
          status_match = line.match(/STATUS:\s*(.+?)(?:\s+LOCATION:|$)/)
          production[:status] = status_match[1].strip if status_match
          
          location_match = line.match(/LOCATION:\s*(.+)/)
          production[:location] = location_match[1].strip if location_match
        end
        
        # Extract people information
        extract_people_from_line(line, production)
        
        # Extract company information  
        extract_companies_from_line(line, production)
      end
      
      def self.extract_people_from_line(line, production)
        # Producer
        if line.match?(/PRODUCER:/)
          producer_text = line[/PRODUCER:\s*(.+?)(?:WRITER|DIRECTOR|SHOWRUNNER|LP:|PM:|PC:|DP:|1AD:|CD:|$)/, 1]
          if producer_text
            names = split_concatenated_names(producer_text)
            names.each do |name|
              production[:people] << { name: name, role: 'Producer' }
            end
          end
        end
        
        # Director
        if line.match?(/DIRECTOR:/)
          director_text = line[/(?:WRITER\/)?DIRECTOR:\s*(.+?)(?:\s+LP:|PM:|PC:|DP:|1AD:|CD:|$)/, 1]
          if director_text
            names = split_concatenated_names(director_text)
            names.each do |name|
              production[:people] << { name: name, role: 'Director' }
            end
          end
        end
        
        # Writer (can be WRITER/DIRECTOR)
        if line.match?(/WRITER/)
          writer_text = line[/WRITER[\/]?[A-Z]*:\s*(.+?)(?:DIRECTOR|LP:|PM:|PC:|DP:|1AD:|CD:|$)/, 1]
          if writer_text && !writer_text.match?(/DIRECTOR/) # Avoid double-counting WRITER/DIRECTOR
            names = split_concatenated_names(writer_text)
            names.each do |name|
              production[:people] << { name: name, role: 'Writer' }
            end
          end
        end
        
        # Other crew roles
        roles_patterns = {
          'Showrunner' => /SHOWRUNNER:\s*(.+?)(?:\s+DIRECTOR|LP:|PM:|PC:|DP:|1AD:|CD:|$)/,
          'Line Producer' => /\bLP:\s*(.+?)(?:PM:|PC:|DP:|1AD:|CD:|$)/,
          'Production Manager' => /\bPM:\s*(.+?)(?:PC:|DP:|1AD:|CD:|$)/,
          'Production Coordinator' => /\bPC:\s*(.+?)(?:DP:|1AD:|CD:|$)/,
          'Director of Photography' => /\bDP:\s*(.+?)(?:1AD:|CD:|$)/,
          'First Assistant Director' => /\b1AD:\s*(.+?)(?:CD:|$)/,
          'Casting Director' => /\bCD:\s*(.+?)$/
        }
        
        roles_patterns.each do |role, pattern|
          match = line.match(pattern)
          if match && match[1].present?
            names = split_concatenated_names(match[1])
            names.each do |name|
              production[:people] << { name: name, role: role }
            end
          end
        end
      end
      
      def self.extract_companies_from_line(line, production)
        # Company names are usually all caps and contain company keywords
        if line.match?(/^[A-Z][A-Z\s&.(),\-]*(?:PRODUCTIONS?|FILMS?|ENTERTAINMENT|STUDIOS?|MEDIA|PICTURES|COMPANY|CORPORATION|LLC|INC|GROUP|AGENCY|CAPITAL)/)
          company_name = fix_concatenated_text(line.strip)
          
          # Extract emails from this line or nearby lines
          emails = line.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i)
          
          production[:companies] << {
            name: company_name,
            role: determine_company_role(company_name),
            emails: emails,
            phones: []
          }
        end
        
        # Phone/Fax lines
        if line.match?(/PHONE:|FAX:/) && production[:companies].any?
          phones = line.scan(/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/)
          production[:companies].last[:phones].concat(phones) if phones.any?
        end
        
        # Standalone email lines
        emails = line.scan(/^\s*[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i)
        if emails.any? && production[:companies].any?
          production[:companies].last[:emails].concat(emails)
        end
      end
      
      def self.split_concatenated_names(text)
        return [] if text.blank?
        
        # Clean up common concatenations
        clean_text = text.dup
        
        # Handle specific patterns like "CairoCannonWRITER" -> "Cairo Cannon"  
        clean_text = clean_text.gsub(/(WRITER|DIRECTOR|PRODUCER|SHOWRUNNER)/i, '')
        
        # Add spaces before capital letters
        clean_text = fix_concatenated_text(clean_text)
        
        # Split on likely boundaries (like " - " or multiple capitals)
        names = clean_text.split(/\s*-\s*|\s*\/\s*/)
        
        # Clean and filter names
        names.map(&:strip)
             .reject(&:blank?)
             .reject { |name| name.length < 3 }
             .reject { |name| name.match?(/^(LP|PM|PC|DP|AD|CD)$/i) } # Remove role abbreviations
      end
      
      def self.determine_company_role(name)
        case name.upcase
        when /PRODUCTIONS?/
          'Production Company'
        when /STUDIOS?|PICTURES/
          'Studio'
        when /ENTERTAINMENT|MEDIA|NETWORK|DISTRIBUTION/
          'Network / Distributor'
        when /NETFLIX|HBO|APPLE|AMAZON|PRIME|PEACOCK|HALLMARK/
          'Network'
        else
          'Company'
        end
      end
      
      def self.extract_description(content_lines)
        return nil if content_lines.blank?
        
        # Look for long descriptive paragraphs
        description_lines = content_lines.select do |line|
          # Should be long enough to be descriptive
          line.length > 50 &&
          # Shouldn't contain technical/contact info
          !line.match?(/STATUS:|LOCATION:|PRODUCER:|DIRECTOR:|WRITER:|CAST:|LP:|PM:|PC:|DP:|1AD:|CD:|PHONE:|FAX:|EMAIL:|@/) &&
          # Shouldn't be a company name
          !line.match?(/^[A-Z][A-Z\s&.(),\-]*(?:PRODUCTIONS?|FILMS?|ENTERTAINMENT|STUDIOS?|MEDIA|PICTURES|COMPANY|CORPORATION)/)
        end
        
        if description_lines.any?
          # Join and clean up
          description = description_lines.join(' ')
          # Fix concatenated words in description
          description = fix_concatenated_text(description)
          description.strip
        end
      end
    end

    puts "Starting fixed data import from '#{text_file_path}'..."
    start_time = Time.now
    productions_imported = 0
    companies_created = 0
    people_created = 0
    errors = []

    # Read and parse PDF
    begin
      pdf_reader = PDF::Reader.new(text_file_path)
      file_content = pdf_reader.pages.map(&:text).join("\n")
      
      productions = FixedPDFParser.parse_pdf_content(file_content)
      
      puts "Found #{productions.length} productions to import"
    rescue => e
      puts "Error reading PDF: #{e.message}"
      exit
    end

    # Clear existing data if needed
    if ARGV.include?('--clear')
      puts "Clearing existing data..."
      Production.destroy_all
      Company.destroy_all
      Person.destroy_all
    end

    ActiveRecord::Base.transaction do
      productions.each_with_index do |production_data, index|
        begin
          next if production_data[:title].blank?

          # Create or find production
          production = Production.find_or_initialize_by(title: production_data[:title])
          
          is_new = production.new_record?
          productions_imported += 1 if is_new
          
          production.assign_attributes(
            production_type: production_data[:production_type],
            network: production_data[:network], 
            status: production_data[:status],
            location: production_data[:location],
            description: production_data[:description]
          )
          
          production.save!
          
          puts "#{is_new ? '✓ Created' : '↻ Updated'}: '#{production.title}'"
          puts "  Type: #{production.production_type}" if production.production_type.present?
          puts "  Network: #{production.network}" if production.network.present?
          puts "  Status: #{production.status}" if production.status.present?
          puts "  Location: #{production.location}" if production.location.present?

          # Process companies
          production_data[:companies]&.each do |company_data|
            next if company_data[:name].blank?
            
            company = Company.find_or_initialize_by(name: company_data[:name])
            
            if company.new_record?
              company.role = company_data[:role]
              company.save!
              companies_created += 1
            end

            # Link to production
            ProductionCompany.find_or_create_by(
              production: production,
              company: company
            )

            # Add emails
            company_data[:emails]&.each do |email|
              EmailAddress.find_or_create_by(
                company: company,
                email: email.downcase
              )
            end
            
            # Add phones
            company_data[:phones]&.each do |phone|
              PhoneNumber.find_or_create_by(
                company: company,
                number: phone
              )
            end
          end

          # Process people
          production_data[:people]&.each do |person_data|
            next if person_data[:name].blank?
            
            person = Person.find_or_create_by(name: person_data[:name])
            people_created += 1 if person.previously_new_record?
            
            role = Role.find_or_create_by(name: person_data[:role])
            
            Credit.find_or_create_by(
              production: production,
              person: person,
              role: role
            )
          end

        rescue => e
          error_msg = "Error importing '#{production_data[:title]}': #{e.message}"
          errors << error_msg
          puts "✗ #{error_msg}"
        end
      end
    end

    end_time = Time.now
    duration = end_time - start_time
    
    puts "\n" + "="*60
    puts "FIXED IMPORT SUMMARY"
    puts "="*60
    puts "✓ Productions: #{productions_imported}"
    puts "✓ Companies: #{companies_created}" 
    puts "✓ People: #{people_created}"
    puts "✗ Errors: #{errors.length}"
    puts "⏱  Time: #{format('%.2f', duration)} seconds"
    
    if errors.any?
      puts "\nErrors:"
      errors.each_with_index do |error, i|
        puts "#{i + 1}. #{error}"
      end
    end
    
    puts "\n📊 Final database totals:"
    puts "   - #{Production.count} productions"
    puts "   - #{Company.count} companies"  
    puts "   - #{Person.count} people"
    puts "   - #{EmailAddress.count} emails"
    puts "   - #{PhoneNumber.count} phones"
  end
end