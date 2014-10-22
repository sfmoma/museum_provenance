module MuseumProvenance

  # A utility class for extracting dates in strings.
  # Used on top of Chronic, but first tries to pull dates with lesser 
  # precision out of the text.
  class DateExtractor
    
    # Find dates within a string.
    # 
    # @example
    #  DateExtractor.find_dates_in_string("my favorite day was January 15, 1980, when I learned about ice cream.")
    #  # returns [Tue, 15 Jan 1980]
    #  
    #  DateExtractor.find_dates_in_string("the 15th Century was hard, but the 1980s were harder.")
    #  # returns [Sat, 01 Jan 1401, Tue, 01 Jan 1980]
    #  
    #  DateExtractor.find_dates_in_string("I like cheese.")
    #  # returns []
    #
    # @param str [String] The string to search for dates
    # @return [Array<Date>] An array of dates found within the string
    def DateExtractor.find_dates_in_string(str)

          centuries = extract_centuries(str)
          decades = extract_decades(str)
          years = extract_years(str)
          months = extract_months(str)
          days = extract_days(str)

          [centuries, decades, years, months, days].flatten.compact
        end
      end

      private

      def DateExtractor.extract_centuries(str) 
        century_regex = /\b(\d{1,2})(?:st|rd|th|nd)?\s+century(?:\s+(ad|bc|bce|ce))?\b/i
        centuries = []
        century = str.match century_regex
        until century.nil?
          centuries.push century
          century = century.post_match.match century_regex
        end
        centuries = centuries.collect do |c|
          is_BCE = c[2] && (c[2].upcase == "BC" || c[2].upcase == "BCE")
          
          val = (c[1].to_s + "01").to_i - 100
          val = ((val + 99) * -1) if is_BCE
         
          century = Date.new(val)
          century.precision = DateTimePrecision::CENTURY
          century
        end
      end

      def DateExtractor.extract_decades(str)
        decade_regex =/\b(\d{1,3})0s(?:\s+(?:ad|bc|bce|ce))?\b/i
        decades = []
        decade = str.match decade_regex
        until decade.nil?
          decades.push decade
          decade = decade.post_match.match decade_regex
        end

        decades.collect do |d|
          val = (d[1].to_s + "0").to_i
          decade = Date.new(val)
          decade.precision = DateTimePrecision::DECADE
          decade
        end
      end

      def DateExtractor.extract_years(str)
          years_regex = /
            (?<!(?:january|febuary|october)\s) # ignore months...
            (?<!(?:march|april)\s)
            (?<!(?:june|july|sept)\s)
            (?<!(?:august)\s)
            (?<!(?:september)\s)
            (?<!(?:december|november|february)\s)
            (?<!(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s)
            (?<!(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\.\s) # ...lots of months, these ones with the dot
            (?<!\d,\s)  # preceding digit and comma, for jan 1, 2014, to ignore the 1
            (?<!\d\s)  # preceding digit, for jan 1 2014, to ignore the 1
            (?<!\d(?:st|rd|th|nd)\s)  # ordinal, for jan 1st 2014, to ignore the 1
            (?<!\d(?:st|rd|th|nd),\s)  # preceding digit, for jan 1st, 2014, to ignore the 1
            \b
            (\d{1,4}) # capture year
            (?:\s+(ad|bc|bce|ce))? # optionally capture era
            \b  
            (?!\scentury) # ignore centuries
          /ix
          years = []
          year = str.match years_regex
          until year.nil?
            years.push year
            year = year.post_match.match years_regex
          end
          
          years.collect do |c|
            is_BCE = c[2] && (c[2].upcase == "BC" || c[2].upcase == "BCE")

            val = c[1].to_i
            val = val * -1 if is_BCE
            Date.new(val)
          end
      end

      def DateExtractor.extract_months(str)
        month_regex =/\b
                         (?:jan|january|feb|february|febuary|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)
                         \.?,?    # possible punctuation
                         \s       # and a space 
                         \d{1,4}  # the year
                         (?:\s+(ad|bc|bce|ce))?  # the optional era
                         (?!,)       # skip it if it is followed by a comma , which might be a BAD IDEA. 
                         (?!\s\d)    # skip it if it is followed by a digit
                         \b
                       /ix
          months = []
          month = str.match month_regex
          until month.nil?
            months.push month
            month = month.post_match.match month_regex
          end

          months.collect do |d|
            val = Chronic.parse(d[0].to_s).to_date
            Date.new(val.year,val.month)
          end
      end

      def DateExtractor.extract_days(str)
        day_regex = /\b
                      (?:jan|january|feb|february|febuary|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)
                      \.?,?\s\d{1,2}
                      (?:st|rd|th|nd)?\s?
                      ,?
                      \s\d{1,4}
                      (?:\s+(?:ad|bc|bce|ce))?\b
                    /ix
          days = []
          day = str.match day_regex
          until day.nil?
            days.push day
            day = day.post_match.match day_regex
          end

          days.collect do |d|
            Chronic.parse(d[0].to_s).to_date
          end
      end
    end