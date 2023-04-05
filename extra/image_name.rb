# require 'fileutils'
require 'rtesseract'
require 'filemagic'

class ExtractNameFromImage
  def move_images_from_folder(path)
    count = 0
    Dir.glob("#{path}/**/*") do |file|
      fm = FileMagic.new
      res = fm.file(file, true)
      if res != "png" && res != "jpeg"
        next
      end
      file_txt = file + ".txt"
      puts "file_txt = #{file_txt}"
      if File.exist?(file_txt)
        next
      end
      image = RTesseract.new(file, lang: 'chi_sim+chi_tra')
      text = image.to_s
      File.open(file_txt, 'w') { |ft| ft.write(text) }
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