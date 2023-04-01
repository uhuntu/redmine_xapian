# require 'fileutils'
require 'rtesseract'
require 'filemagic'

class ExtractNameFromImage
  def move_images_from_folder(path)
    count = 0
    Dir.glob("#{path}/**/*") do |file|
      # puts "file = #{file}"
      fm = FileMagic.new
      res = fm.file(file, true)
      # puts "res = #{res}"
      if res != "png" && res != "jpeg"
        next
      end
      image = RTesseract.new(file)
      text = image.to_s
      tsv = image.to_tsv  # Getting open file of tsv
      puts "tsv = #{tsv.path}"
      count += 1
      # puts "text = #{text}"
      puts "Ok #{file} scanned #{count}"
    end
  end
end

if ARGV[0].nil?
    puts "No such directory exist, try again"
    return
end

puts "Scanning directory #{ARGV[0]}"
extracter = ExtractNameFromImage.new
if File.directory?(ARGV[0])
  extracter.move_images_from_folder(ARGV[0])
else
  puts "No such directory exist, try again"
end