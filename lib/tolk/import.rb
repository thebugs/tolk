module Tolk
  module Import
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods

      def import_secondary_locales
        locales = Dir.entries(self.locales_config_path)

        locale_block_filter = Proc.new {
            |l| ['.', '..'].include?(l) ||
              !l.ends_with?('.yml')
        }
        locales = locales.reject(&locale_block_filter)
        locales.each {|l| import_locale(l) }
      end

      def import_locale(locale_file)
        data, locale_name = read_file locale_file
        return unless data

        locale = Tolk::Locale.find_or_create_by_name(locale_name)

        phrases = Tolk::Phrase.all
        count = 0

        data.each do |key, value|
          phrase = phrases.detect {|p| p.key == key}

          if phrase
            translation = locale.translations.new(:text => value, :phrase => phrase)
            if translation.save
              count = count + 1
            elsif translation.errors[:variables].present?
              puts "[WARN] Key '#{key}' from '#{locale_file}' could not be saved: #{translation.errors[:variables].first}"
            end
          else
            puts "[ERROR] Key '#{key}' was found in '#{locale_file}' but #{Tolk::Locale.primary_language_name} translation is missing"
          end
        end

        puts "[INFO] Imported #{count} keys from #{locale_file}"
      end

      def read_file(name)
        locale_file = "#{self.locales_config_path}/#{name}"
        raise "Locale file #{locale_file} does not exists" unless File.exists?(locale_file)

        puts "[INFO] Reading #{locale_file}"
        begin
          data = YAML::load(File.read(locale_file))
          locale_name = data.keys.first

          [(locale_name == Tolk::Locale.primary_locale.name ? nil : flat_hash(data[locale_name])), locale_name]
        rescue
          puts "[ERROR] File #{locale_file} expected to declare #{name} locale, but it does not. Skipping this file."
          nil
        end
      end

    end

  end
end
