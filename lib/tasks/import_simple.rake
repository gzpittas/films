# lib/tasks/import_simple.rake
# frozen_string_literal: true

namespace :import do
  desc 'Simple import that focuses on the basics'
  task simple_productions: :environment do
    require 'pdf-reader'

    text_file_path = Rails.root.join('db', 'data', 'production_weekly.pdf')

    unless File.exist?(text_file_path)
      puts "Error: Production data file not found at '#{text_file_path}'"
      exit
    end

    # Seed roles
    puts "Seeding common roles..."
    Role.seed_common_roles!

    puts "Starting simple import..."
    start_time = Time.now
    productions_imported = 0
    companies_created = 0
    people_created = 0

    # Read PDF
    pdf_reader = PDF::Reader.new(text_file_path)
    file_content = pdf_reader.pages.map(&:text).join("\n")
    lines = file_content.split("\n").map(&:strip).reject(&:empty?)

    # Find title lines using a simple approach
    title_lines = lines.select do |line|
      line.match?(/^"[^"]+"\s+(Feature Film|Series|Telefilm|Limited Series|Mini-Series|HBSVOD Feature)/i)
    end

    puts "Found #{title_lines.length} title lines to process"
    
    title_lines.each_with_index do |title_line, index|
      begin
        # Extract title from between Unicode quotes and clean it up
        title_pattern = /#{Regexp.escape(left_quote)}([^#{Regexp.escape(right_quote)}]+)#{Regexp.escape(right_quote)}/
        title_match = title_line.match(title_pattern)
        next unless title_match
        
        raw_title = title_match[1]
        
        # Advanced title cleaning for concatenated words
        title = raw_title
          .gsub(/([a-z\d])([A-Z])/, '\1 \2')           # Add space before capitals after lowercase/digits
          .gsub(/([A-Z])([A-Z][a-z])/, '\1 \2')        # Add space between consecutive capitals
          .gsub(/(\d)(MILES|DAYS|YEARS|HOURS)/i, '\1 \2') # Handle number+word combinations
          .gsub(/(THE)([A-Z])/, '\1 \2')               # Fix "THE" prefix
          .gsub(/([A-Z]{2,})([A-Z][a-z])/, '\1 \2')    # Multiple caps followed by title case
          .squeeze(' ')
          .strip
        
        # Extract type and network
        remainder = title_line.sub(title_pattern, '').strip
        
        production_type = nil
        network = nil
        
        type_match = remainder.match(/(Feature Film|Series|Telefilm|Limited Series|Mini-Series|HBSVOD Feature)/i)
        production_type = type_match[1] if type_match
        
        # Clean network extraction - remove dates and extra characters
        network_match = remainder.match(/\/\s*([^\/\n]+)/)
        if network_match
          network = network_match[1]
            .gsub(/\s+\d{2}-\d{2}-\d{2}.*$/, '')     # Remove dates like "08-14-25ê"
            .gsub(/\s+\d{4}.*$/, '')                 # Remove years
            .strip
        end

        # Create production
        production = Production.find_or_initialize_by(title: title)
        
        is_new = production.new_record?
        productions_imported += 1 if is_new
        
        production.assign_attributes(
          production_type: production_type,
          network: network
        )
        
        production.save!
        
        puts "#{is_new ? '✓' : '↻'} #{title} (#{production_type}#{network ? " / #{network}" : ''})"

        # Look for related information in the next few lines
        start_index = lines.index(title_line)
        next unless start_index
        
        # Process the next 20 lines for this production's info
        related_lines = lines[(start_index + 1)..(start_index + 20)]
        
        related_lines.each do |line|
          break if line.match?(/^"[^"]+"\s+(Feature Film|Series|Telefilm|Limited Series)/i) # Next production
          
          # Status and Location
          if line.match?(/STATUS:/)
            status_match = line.match(/STATUS:\s*(.+?)(?:\s+LOCATION:|$)/)
            production.status = status_match[1].strip if status_match
            
            location_match = line.match(/LOCATION:\s*(.+)/)
            production.location = location_match[1].strip if location_match
            
            production.save!
          end
          
          # Company names (all caps lines)
          if line.match?(/^[A-Z][A-Z\s&.(),\-]*(?:PRODUCTIONS?|FILMS?|ENTERTAINMENT|STUDIOS?|MEDIA|PICTURES|COMPANY|CORPORATION|LLC|INC|GROUP|AGENCY|CAPITAL)/)
            company_name = line.gsub(/([a-z])([A-Z])/, '\1 \2').squeeze(' ').strip
            
            company = Company.find_or_initialize_by(name: company_name)
            if company.new_record?
              company.role = determine_company_role(company_name)
              company.save!
              companies_created += 1
            end
            
            ProductionCompany.find_or_create_by(
              production: production,
              company: company
            )
            
            puts "  + #{company_name}"
          end
          
          # Email addresses
          emails = line.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i)
          if emails.any? && production.companies.any?
            emails.each do |email|
              EmailAddress.find_or_create_by(
                company: production.companies.last,
                email: email.downcase
              )
            end
            puts "  📧 #{emails.join(', ')}"
          end
          
          # Extract people from PRODUCER/DIRECTOR lines
          if line.match?(/PRODUCER:|DIRECTOR:|WRITER:/)
            extract_people_from_line(line, production)
          end
        end

      rescue => e
        puts "✗ Error processing '#{raw_title}': #{e.message}"
      end
    end

    end_time = Time.now
    duration = end_time - start_time
    
    puts "\n" + "="*50
    puts "SIMPLE IMPORT COMPLETE"
    puts "="*50
    puts "✓ Productions: #{productions_imported}"
    puts "✓ Companies: #{companies_created}"
    puts "✓ People: #{people_created}"
    puts "⏱  Time: #{format('%.2f', duration)} seconds"
    puts "\n📊 Database totals:"
    puts "   - #{Production.count} productions"
    puts "   - #{Company.count} companies"
    puts "   - #{Person.count} people"
    puts "   - #{EmailAddress.count} emails"
  end

  private

  def determine_company_role(name)
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

  def extract_people_from_line(line, production)
    # Simple extraction of people
    if line.match?(/PRODUCER:/)
      text = line[/PRODUCER:\s*(.+?)(?:WRITER|DIRECTOR|SHOWRUNNER|$)/, 1]
      if text
        names = text.split(/\s*-\s*/).map { |name| clean_name(name) }
        names.each do |name|
          next if name.blank?
          person = Person.find_or_create_by(name: name)
          role = Role.find_or_create_by(name: 'Producer')
          Credit.find_or_create_by(production: production, person: person, role: role)
        end
      end
    end
    
    if line.match?(/DIRECTOR:/)
      text = line[/DIRECTOR:\s*(.+?)(?:LP:|PM:|PC:|$)/, 1]
      if text
        names = text.split(/\s*-\s*/).map { |name| clean_name(name) }
        names.each do |name|
          next if name.blank?
          person = Person.find_or_create_by(name: name)
          role = Role.find_or_create_by(name: 'Director')
          Credit.find_or_create_by(production: production, person: person, role: role)
        end
      end
    end
  end

  def clean_name(name)
    return nil if name.blank?
    
    # Remove common suffixes and clean up
    clean = name.gsub(/(WRITER|DIRECTOR|PRODUCER)/i, '')
              .gsub(/([a-z])([A-Z])/, '\1 \2')
              .squeeze(' ')
              .strip
    
    clean.length > 2 ? clean : nil
  end
end