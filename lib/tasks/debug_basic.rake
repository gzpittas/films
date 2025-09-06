# lib/tasks/debug_basic.rake
namespace :debug do
  desc 'Basic debug to see what we actually have'
  task basic_import: :environment do
    require 'pdf-reader'

    text_file_path = Rails.root.join('db', 'data', 'production_weekly.pdf')

    puts "Reading PDF..."
    pdf_reader = PDF::Reader.new(text_file_path)
    file_content = pdf_reader.pages.map(&:text).join("\n")
    lines = file_content.split("\n").map(&:strip).reject(&:empty?)

    puts "Total lines: #{lines.length}"
    
    puts "\nFirst 20 lines:"
    lines.first(20).each_with_index do |line, i|
      puts "#{i}: #{line}"
    end
    
    puts "\nLines containing quotes:"
    quote_lines = lines.select { |line| line.include?('"') }
    puts "Found #{quote_lines.length} lines with quotes"
    quote_lines.first(10).each_with_index do |line, i|
      puts "#{i}: #{line}"
    end
    
    puts "\nLines containing 'Feature Film' or 'Series':"
    type_lines = lines.select { |line| line.match?(/(Feature Film|Series)/i) }
    puts "Found #{type_lines.length} lines with production types"
    type_lines.first(10).each_with_index do |line, i|
      puts "#{i}: #{line}"
    end
    
    puts "\nLines with BOTH quotes AND production types:"
    both_lines = lines.select { |line| line.include?('"') && line.match?(/(Feature Film|Series|Telefilm)/i) }
    puts "Found #{both_lines.length} lines with both"
    both_lines.first(10).each_with_index do |line, i|
      puts "#{i}: #{line}"
    end
  end
end