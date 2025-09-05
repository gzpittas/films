# lib/tasks/debug_import.rake
namespace :debug do
  desc 'Debug PDF parsing to see what we get'
  task pdf: :environment do
    require 'pdf-reader'

    text_file_path = Rails.root.join('db', 'data', 'production_weekly.pdf')

    unless File.exist?(text_file_path)
      puts "Error: Production data file not found at '#{text_file_path}'"
      exit
    end

    # Read PDF
    pdf_reader = PDF::Reader.new(text_file_path)
    file_content = pdf_reader.pages.map(&:text).join("\n")
    
    puts "="*60
    puts "RAW CONTENT (first 1000 characters):"
    puts "="*60
    puts file_content[0..1000]
    puts "\n"
    
    # Clean content
    file_content = file_content.gsub(/Production Weekly.*?Downloaded by.*?\n/m, '')
    file_content = file_content.gsub(/© Copyright.*?\n/, '')
    
    puts "="*60
    puts "CLEANED CONTENT (first 1000 characters):"
    puts "="*60
    puts file_content[0..1000]
    puts "\n"
    
    # Test different quote patterns
    straight_quote_blocks = file_content.scan(/(^"[^"]*".*?)(?=^"|$)/m)
    curly_quote_blocks = file_content.scan(/(^[""][^""]*[""].*?)(?=^[""]|$)/m)
    any_quote_blocks = file_content.scan(/(^[""][^""]*[""].*?)(?=^[""]|$)/m)
    
    puts "="*60
    puts "QUOTE PATTERN RESULTS:"
    puts "="*60
    puts "Straight quotes (\") found: #{straight_quote_blocks.length} blocks"
    puts "Curly quotes ("") found: #{curly_quote_blocks.length} blocks"
    
    if curly_quote_blocks.any?
      puts "\nFirst curly quote block:"
      puts "-" * 40
      puts curly_quote_blocks.first[0][0..500]
    end
    
    if straight_quote_blocks.any?
      puts "\nFirst straight quote block:"
      puts "-" * 40
      puts straight_quote_blocks.first[0][0..500]
    end
    
    # Look for lines that start with quotes
    quote_lines = file_content.split("\n").select { |line| line.match?(/^[""]/) }
    puts "\n="*60
    puts "LINES STARTING WITH QUOTES (first 10):"
    puts "="*60
    quote_lines.first(10).each_with_index do |line, i|
      puts "#{i+1}. #{line[0..100]}..."
    end
  end
end