# lib/tasks/import_fixed.rake
# frozen_string_literal: true

namespace :import do
  desc 'Fixed import with correct quote detection'
  task fixed_productions: :environment do
    require 'pdf-reader'
    require 'csv'

    text_file_path = Rails.root.join('db', 'data', 'production_weekly.pdf')

    unless File.exist?(text_file_path)
      puts "Error: Production data file not found at '#{text_file_path}'"
      exit
    end

    puts "Seeding common roles..."
    Role.seed_common_roles!

    class FixedPDFParser
      def self.parse_pdf_content(file_content)
        lines = file_content.split("\n").map(&:strip).reject(&:empty?)
        
        productions = []
        current_production = nil
        i = 0
        
        while i < lines.length
          line = lines[i]
          
          if is_title_line?(line)
            productions << current_production if current_production && current_production[:title].present?
            
            current_production = parse_title_line(line)
            current_production[:companies] = []
            current_production[:people] = []
            current_production[:content_lines] = []
            
            puts "Found production title: '#{current_production[:title]}'"
            
          elsif current_production
            current_production[:content_lines] << line
            parse_production_line(line, current_production)
          end
          
          i += 1
        end
        
        productions << current_production if current_production && current_production[:title].present?
        
        productions.each do |prod|
          prod[:description] = extract_description(prod[:content_lines])
        end
        
        productions
      end
      
      def self.is_title_line?(line)
        # 💡 NEW REGEX: Accounts for both straight quotes (") and smart quotes (“ and ”)
        line.match?(/["“”][^"“”]+["“”]\s*(?:\d+\s*)?(?:Feature Film|Series|Telefilm|Limited Series|HBSVOD Feature)(?:\s*\/.*)?/i)
      end
      
      def self.parse_title_line(line)
        title_match = line.match(/["“”]([^"“”]+)["“”]/)
        title = title_match[1] if title_match
        
        if title
          title = fix_concatenated_text(title)
        end
        
        remainder = line.sub(/["“”][^"“”]+["“”]/, '').strip
        
        production_type = nil
        network = nil
        
        type_match = remainder.match(/(Feature Film|Series|Telefilm|Limited Series|HBSVOD Feature)/i)
        production_type = type_match[1] if type_match
        
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
        fixed_text = text.gsub(/([a-z\d])([A-Z])/, '\1 \2')
        fixed_text = fixed_text.gsub(/(\d)(MILES|DAYS|YEARS)/i, '\1 \2')
        fixed_text.squeeze(' ').strip
      end
      
      def self.parse_production_line(line, production)
        if line.match?(/STATUS:/)
          status_match = line.match(/STATUS:\s*(.+?)(?:\s+LOCATION:|$)/)
          production[:status] = status_match[1].strip if status_match
          
          location_match = line.match(/LOCATION:\s*(.+)/)
          production[:location] = location_match[1].strip if location_match
        end
        
        extract_people_from_line(line, production)
        extract_companies_from_line(line, production)
      end
      
      def self.extract_people_from_line(line, production)
        roles_patterns = {
          'Producer' => /PRODUCER:\s*(.+?)(?:WRITER|DIRECTOR|SHOWRUNNER|LP:|PM:|PC:|DP:|1AD:|CD:|$)/,
          'Writer' => /WRITER[\/]?[A-Z]*:\s*(.+?)(?:DIRECTOR|LP:|PM:|PC:|DP:|1AD:|CD:|$)/,
          'Director' => /DIRECTOR:\s*(.+?)(?:\s+LP:|PM:|PC:|DP:|1AD:|CD:|$)/,
          'Showrunner' => /SHOWRUNNER:\s*(.+?)(?:\s+DIRECTOR|LP:|PM:|PC:|DP:|1AD:|CD:|$)/,
          'Line Producer' => /\bLP:\s*(.+?)(?:PM:|PC:|DP:|1AD:|CD:|$)/,
          'Production Manager' => /\bPM:\s*(.+?)(?:PC:|DP:|1AD:|CD:|$)/,
          'Production Coordinator' => /\bPC:\s*(.+?)(?:DP:|1AD:|CD:|$)/,
          'Director of Photography' => /\bDP:\s*(.+?)(?:1AD:|CD:|$)/,
          'First Assistant Director' => /\b1AD:\s*(.+?)(?:CD:|$)/,
          'Casting Director' => /\bCD:\s*(.+?)$/
        }

        roles_patterns.each do |role, pattern|
          next if role == 'Writer' && line.match?(/WRITER\/DIRECTOR:/)
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
        if line.match?(/^[A-Z][A-Z\s&.(),\-]*(?:PRODUCTIONS?|FILMS?|ENTERTAINMENT|STUDIOS?|MEDIA|PICTURES|COMPANY|CORPORATION|LLC|INC|GROUP|AGENCY|CAPITAL)/)
          company_name = fix_concatenated_text(line.strip)
          emails = line.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i)
          production[:companies] << {
            name: company_name,
            role: determine_company_role(company_name),
            emails: emails,
            phones: []
          }
        end
        
        if line.match?(/PHONE:|FAX:/) && production[:companies].any?
          phones = line.scan(/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/)
          production[:companies].last[:phones].concat(phones) if phones.any?
        end
        
        emails = line.scan(/^\s*[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i)
        if emails.any? && production[:companies].any?
          production[:companies].last[:emails].concat(emails)
        end
      end
      
      def self.split_concatenated_names(text)
        return [] if text.blank?
        clean_text = text.dup
        clean_text = clean_text.gsub(/(WRITER|DIRECTOR|PRODUCER|SHOWRUNNER)/i, '')
        clean_text = fix_concatenated_text(clean_text)
        names = clean_text.split(/\s*-\s*|\s*\/\s*/)
        names.map(&:strip)
             .reject(&:blank?)
             .reject { |name| name.length < 3 }
             .reject { |name| name.match?(/^(LP|PM|PC|DP|AD|CD)$/i) }
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
        description_lines = content_lines.select do |line|
          line.length > 50 &&
          !line.match?(/STATUS:|LOCATION:|PRODUCER:|DIRECTOR:|WRITER:|CAST:|LP:|PM:|PC:|DP:|1AD:|CD:|PHONE:|FAX:|EMAIL:|@/) &&
          !line.match?(/^[A-Z][A-Z\s&.(),\-]*(?:PRODUCTIONS?|FILMS?|ENTERTAINMENT|STUDIOS?|MEDIA|PICTURES|COMPANY|CORPORATION)/)
        end
        
        if description_lines.any?
          description = description_lines.join(' ')
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

    begin
      pdf_reader = PDF::Reader.new(text_file_path)
      file_content = pdf_reader.pages.map(&:text).join("\n")
      
      productions = FixedPDFParser.parse_pdf_content(file_content)
      
      puts "Found #{productions.length} productions to import"
    rescue => e
      puts "Error reading PDF: #{e.message}"
      exit
    end

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

          production_data[:companies]&.each do |company_data|
            next if company_data[:name].blank?
            
            company = Company.find_or_initialize_by(name: company_data[:name])
            
            if company.new_record?
              company.role = company_data[:role]
              company.save!
              companies_created += 1
            end

            ProductionCompany.find_or_create_by(
              production: production,
              company: company
            )

            company_data[:emails]&.each do |email|
              EmailAddress.find_or_create_by(
                company: company,
                email: email.downcase
              )
            end
            
            company_data[:phones]&.each do |phone|
              PhoneNumber.find_or_create_by(
                company: company,
                number: phone
              )
            end
          end

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
    puts "    - #{Production.count} productions"
    puts "    - #{Company.count} companies"
    puts "    - #{Person.count} people"
    puts "    - #{EmailAddress.count} emails"
    puts "    - #{PhoneNumber.count} phones"
  end
end