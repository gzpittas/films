# lib/tasks/minimal_import.rake
namespace :import do
  desc 'Minimal import to test basic functionality'
  task minimal: :environment do
    puts "=== MINIMAL IMPORT STARTING ==="
    
    require 'pdf-reader'
    text_file_path = Rails.root.join('db', 'data', 'production_weekly.pdf')

    pdf_reader = PDF::Reader.new(text_file_path)
    file_content = pdf_reader.pages.map(&:text).join("\n")
    lines = file_content.split("\n").map(&:strip).reject(&:empty?)

    puts "Total lines read: #{lines.length}"
    
    # Look for the specific lines we know exist
    target_lines = [
      '"7MILESOUT"      Feature Film',
      '"1874"  Series / Hallmark'
    ]
    
    # Use the actual Unicode smart quote characters
    left_quote = "\u201C"   # Unicode left double quotation mark "
    right_quote = "\u201D"  # Unicode right double quotation mark "
    
    puts "Using Unicode quotes: '#{left_quote}' and '#{right_quote}'"
    
    # Find title lines with correct Unicode quotes
    title_lines = lines.select do |line|
      line.include?(left_quote) && line.include?(right_quote) && 
      line.match?(/(Feature Film|Series|Telefilm|Limited Series|Mini-Series)/i)
    end
    
    puts "Found #{title_lines.length} title lines with Unicode quotes"
    
    # Process each title line
    title_lines.each do |line|
      puts "\nProcessing: #{line}"
      
      # Extract title from between Unicode quotes
      title_pattern = /#{Regexp.escape(left_quote)}([^#{Regexp.escape(right_quote)}]+)#{Regexp.escape(right_quote)}/
      title_match = line.match(title_pattern)
      
      if title_match
        raw_title = title_match[1]
        # Clean up concatenated title
        clean_title = raw_title.gsub(/([a-z\d])([A-Z])/, '\1 \2')
                               .gsub(/(\d)(MILES|DAYS|YEARS)/i, '\1 \2')
                               .squeeze(' ')
                               .strip
        
        # Extract production type
        type_match = line.match(/(Feature Film|Series|Telefilm|Limited Series|Mini-Series)/i)
        production_type = type_match[1] if type_match
        
        # Extract network if present
        network_match = line.match(/\/\s*([^\/\n]+)/)
        network = network_match[1].strip if network_match
        
        puts "  Title: #{clean_title}"
        puts "  Type: #{production_type}"
        puts "  Network: #{network}" if network
        
        # Create production
        begin
          production = Production.create!(
            title: clean_title,
            production_type: production_type,
            network: network
          )
          puts "  ✓ Created production: #{production.id}"
        rescue => e
          puts "  ✗ Error: #{e.message}"
        end
      end
    end
    
    puts "=== MINIMAL IMPORT COMPLETE ==="
  end
end