module MuseumProvenance
  
  # {Period} is a representation of a single event within a {Timeline}.
  #
  # It also functions as a linked list, where each period has a {#previous_period} and {#next_period},
  # and periods can be inserted before and after.   
  class Period

    # The string used to indicate uncertainty for an entire period.
    PERIOD_CERTAINTY_STRING = "Possibly"

    prepend Certainty   

    # @!attribute [rw] acquisition_method
    #   @return [AcquisitionMethod] The method of acqusition of this period. 

    # @!attribute [rw] note
    #   @return [String] The footnote associated with this period. 

    # @!attribute [rw] original_text
    #   The text used to generate this record.
    #   This is the text used for verification and comparison against the generated record.  
    #   It can be manually set if needed.
    #
    #   @return [String]  

    # @!attribute [rw] primary_owner
    #   Is the owner a primary owner, or a dealer, sale, or gallery?
    #   This is a concept defined in the AAM standard for Provenance.  In the standard,
    #   non-primary owners have their record defined by wrapping the provenance clause in parentheses.
    #   
    #   @return [Boolean] Returns true if the owner is considered a primary owner. 

    # @!attribute [rw] stock_number
    #   @depreciated true
    #   @return [String] The stock number of the artwork in the collection of this owner.

    # @!attribute [r] party
    #   @return [Party] The party who owned the work during this period. 

    # @!attribute [r] location
    #   @return [Location] The location where the artwork was located during this period. 

    # @!attribute [r] next_period
    #   @return [Period] The location immediately preceding this period within the record. 


    # @!attribute [r] previous_period
    #   @return [Period] The location immediately following this period within the record.


    attr_reader  :next_period, :previous_period, :party, :location
    attr_accessor  :acquisition_method, :note, :original_text, :stock_number, :primary_owner


    # Create a new [Period}.
    # @todo replace the generic hash with a PeriodOutput.
    # @param _name [String] The party name of the Period
    # @param opts [Hash] allows a period to be initialized using a hash.
    def initialize(_name = "", opts=Hash.new)
      begin
        @direct_transfer = false
        self.primary_owner = true

        self.party = _name 

        # remove blank values
        opts.delete_if { |k, v| (v.is_a?(String) && v.empty?) }

        # Intialize party
        self.party  = opts[:party] if opts[:party]
        @party.certain= opts[:party_certainty].to_bool unless opts[:party_certainty].nil?
        if opts[:birth]
          @party.birth= Date.jd(opts[:birth].to_i)
          @party.birth.certainty= opts[:birth_certainty].to_bool unless opts[:birth_certainty].nil?
          @party.birth.precision= DateTimePrecision::YEAR
        end
        if opts[:death]

          death_year = Time.at(opts[:death].to_i).to_date.year
          @party.death= Date.new(Date.jd(opts[:death].to_i).year)
          @party.death.certainty= opts[:death_certainty].to_bool unless opts[:death_certainty].nil?
          @party.death.precision = DateTimePrecision::YEAR
        end

        # Initialize global state
        self.acquisition_method = AcquisitionMethod.find_by_name(opts[:acquisition_method]) 
        self.certainty = opts[:period_certainty].to_bool unless opts[:period_certainty].nil?
        self.primary_owner = opts[:primary_owner].to_bool unless opts[:primary_owner].nil?

        # initialize location
        if opts[:location]
          self.location = opts[:location]
          self.location.certain = opts[:location_certainty].to_bool unless opts[:location_certainty].nil?
        end
        # intialize metadata
        self.stock_number = opts[:stock_number]
        unless opts[:footnote].blank?
          #puts "opts[:footnote]: #{opts[:footnote]}"
          self.note = [opts[:footnote]]
        end

        # intitialze dates
        if opts[:bote]
          b_o_t_e = Date.jd(opts[:bote].to_i)
          b_o_t_e.certainty = opts[:bote_certainty].to_bool unless opts[:bote_certainty].nil?
          b_o_t_e.precision = opts[:bote_precision].to_f unless opts[:bote_precision].nil?
        end
        if opts[:eote]
          e_o_t_e = Date.jd(opts[:eote].to_i)
          e_o_t_e.certainty = opts[:eote_certainty].to_bool unless opts[:eote_certainty].nil?
          e_o_t_e.precision = opts[:eote_precision].to_f unless opts[:eote_precision].nil?
        end
        if opts[:botb]
          b_o_t_b =  Date.jd(opts[:botb].to_i)
          b_o_t_b.certainty = opts[:botb_certainty].to_bool unless opts[:botb_certainty].nil?
          b_o_t_b.precision = opts[:botb_precision].to_f unless opts[:botb_precision].nil?
        end
        if opts[:eotb]
          e_o_t_b =  Date.jd(opts[:eotb].to_i)
          e_o_t_b.certainty = opts[:eotb_certainty].to_bool unless opts[:eotb_certainty].nil?
          e_o_t_b.precision = opts[:eotb_precision].to_f unless opts[:eotb_precision].nil?
        end
        @beginning = TimeSpan.new(b_o_t_b,e_o_t_b) if b_o_t_b || e_o_t_b
        @ending = TimeSpan.new(b_o_t_e,e_o_t_e)    if b_o_t_e || e_o_t_e 
      rescue => e
        puts "\nProblem with this period:\n"
        puts e
        puts opts.inspect
        puts "\n"
      end
     end




     # Denormalize the period into a {PeriodOutput}.
     # @return [PeriodOutput] a populated Struct containing the {Period}'s information.
     def generate_output
       o = PeriodOutput.new
       o.period_certainty = self.certainty
       o.acquisition_method = acquisition_method.name if acquisition_method
       o.party = self.party.name
       o.party_certainty =self.party.certainty
       o.death = self.party.death.latest if self.party.death
       o.death_certainty = self.party.death.certainty
       o.birth = self.party.birth.earliest if self.party.birth
       o.birth_certainty = self.party.birth.certainty
       if location
         o.location = self.location.name
         o.location_certainty = self.location.certainty
       end
       if @beginning
         o.botb = @beginning.earliest_raw
         o.botb_certainty = @beginning.earliest_raw.certainty
         o.botb_precision = @beginning.earliest_raw.precision
         o.eotb = @beginning.latest_raw
         o.eotb_certainty = @beginning.latest_raw.certainty
         o.eotb_precision = @beginning.latest_raw.precision
       end
       if @ending
         o.bote = @ending.earliest_raw
         o.bote_certainty = @ending.earliest_raw.certainty
         o.bote_precision = @ending.earliest_raw.precision
         o.eote = @ending.latest_raw
         o.eote_certainty = @ending.latest_raw.certainty
         o.eote_precision = @ending.latest_raw.precision
       end
       o.original_text = self.original_text
       o.provenance = self.provenance
       o.parsable = self.parsable?
       o.direct_transfer = self.direct_transfer?
       o.stock_number = self.stock_number
       o.footnote = self.note.join("; ") if self.note
       o.primary_owner = self.primary_owner
       return o
     end

     # Denormalize the period into a [Hash]
     # @return [Hash] a hash of the {Period}'s information.
     def to_h
       generate_output.to_h
     end

     # Extract a time phrase out of a string, and use it to set the dates for this period.
     #
     # There's an entire article on the site about the various phrases for this.
     #
     # @param str [String] the string to search for a time reference
     # @param recursion_count [Fixnum] Used to count number of recursions to prevent infinite recursion
     # @return [String] the string with the time reference removed
     def parse_time_string(str)
        b, e = str.split("until")
        actually_parse_time_string(str)
     end



     def actually_parse_time_string(str, recursion_count = 0) 
      time_debug = false# str.include? "Newcastle"

      puts str if time_debug
      if str.strip == "" && recursion_count == 0
        self.beginning = nil
        self.ending = nil
        return ""
      end
      raise DateError, "Too much recursion" if recursion_count > 10

      #substitution for (horrible) date pattern:  "1985-86" becomes "1985 until 1986"
      horrid_date_range_regex = /(\d{2})(\d{2})\s?[-–—]\s?(\d{2})(?!-)\b/
      str.gsub!(horrid_date_range_regex,'\1\2 until \1\3')

      #substitution for trivial date pattern: "1918-1919" becomes "1918 until 1919"
      date_range_regex = /(\d{4})\s?[-–—]\s?(\d{4})(?!-)/
      str.gsub!(date_range_regex,'\1 until \2')

      # substitution for "May 5-6, 1980" becomes "May 5, 1980 until May 6, 1980"
      multiday_regex = /(jan|january|feb|february|febuary|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)\s(\d{1,2})\s?[–—-]\s?(\d{1,2}),\s(\d{2,4})/i
      str.gsub!(multiday_regex, '\1 \2, \4 until \1 \3, \4')

      # substitution for "30-31 January 1922" becomes "January 30, 1922 until January 31, 1922"
      multiday_regex_2 = /\s(\d{1,2})\s?[–—-]\s?(\d{1,2})\s(jan|january|feb|february|febuary|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)\,?\s(\d{2,4})/i
      str.gsub!(multiday_regex_2, ' \3 \1, \4 until \3 \2, \4')

      # substitution for "23 October - 12 November 1926"
      multiday_regex_3 = /
         \b(\d{1,2})\s
         (jan|january|feb|february|febuary|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)
         \s?[–—-]\s?
         (\d{1,2})\s
         (jan|january|feb|february|febuary|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)
         \s(\d{1,4})
      /ix
      str.gsub!(multiday_regex_3, ' \2 \1, \5 until \4 \3, \5')
      
      # Substitution for "c. 1945" or "ca. 1945" becomes "circa 1945"
      circa_regex = /\bc(?:a)?\.\s(\d{4})\b/
      str.gsub!(circa_regex, 'circa \1')

      puts  "2: #{str}"  if time_debug


    tokens = ["circa", "on", "before", "by", "as of", "after", "until", "until sometime after", "until at least", "until sometime before", "in", "between","sometime between", "until between", "until sometime between", "to at least"]
      found_token = tokens.collect{|t| str.scan(/\b#{t}(?=\s(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|[1-9]|the\s[1-9]))\b/i).empty? ? nil : t }.compact.sort_by!{|t| t.length}.reverse.first
      puts found_token if time_debug
      if found_token.nil?
        vals = str.split(",")
        
        current_phrase = []
        last_date = nil
        while vals.count >= 1
          word = vals.pop
          current_phrase.unshift word

          # Look for dates that have embedded commas in them.  October 14, 1980, August, 1980
          date_phrase = current_phrase.join(",")
          current_date = DateExtractor.find_dates_in_string(date_phrase).first
          if !current_date.nil? && current_date == last_date && current_date.precision == last_date.precision
            vals.push current_phrase.shift
            break
          end
          last_date = current_date
        end
        str = vals.join(",") 
        date_string = current_phrase.join(',')
        str += DateExtractor.remove_dates_in_string(date_string)
        str.gsub!(/\s\s*/, " ")
      else
        str, date_string = str.split(/\b#{found_token}\b/i)
        date_string.strip! unless date_string.nil?
        str.strip
        puts "3: #{str}, #{date_string}" if  time_debug
      end

      case (found_token.downcase rescue nil)
         when nil
          self.beginning = TimeSpan.parse(date_string)
         when  "on"
           self.beginning = TimeSpan.parse(date_string)
           self.ending = TimeSpan.parse(date_string) if  self.beginning.earliest_raw.precision == DateTimePrecision::DAY
         when "circa"
          self.beginning = TimeSpan.parse(date_string)
          self.beginning.earliest_raw.certainty = false
          self.beginning.latest_raw.certainty = false            
         when "before", "by", "as of"
          self.beginning =TimeSpan.new(nil, date_string)
         when "after"
          self.beginning = TimeSpan.new(date_string,nil)
         when "until sometime after", "until at least", "to at least"
          self.ending = TimeSpan.new(date_string,nil)
         when "until"
            self.ending = TimeSpan.new(date_string,date_string)
         when "until sometime before" 
          self.ending = TimeSpan.new(nil,date_string)
         when "in"
          self.beginning = TimeSpan.new(nil,date_string)
          self.ending = TimeSpan.new(date_string,nil)
         when "between", "sometime between"
          dates = date_string.split(" and ")
          self.beginning = TimeSpan.new(dates[0],dates[1])
          when "until between", "until sometime between"
           dates = date_string.split(" and ")
           self.ending = TimeSpan.new(dates[0],dates[1])
      end
      if str.blank? 
        str =  DateExtractor.remove_dates_in_string(date_string)
      end
      str.strip!
      str.gsub!(/,$/,"") # trailing commas
      str.strip!

      # recursively run until it can't find another date
      begin
        rerun = actually_parse_time_string(str, recursion_count +1)
      rescue DateError
        return str
      end
      return rerun.strip
    end

    # Generate a textual representation of the timeframe of the period.
    # @return [String]
    def time_string
      #  TODO:  What the hell is this?
      if(   @beginning && @ending &&
            !@beginning.latest.nil? && !@ending.earliest.nil? && 
            !@beginning.earliest && !@ending.latest && 
            @beginning.latest.precision == @ending.earliest.precision &&
            @beginning.latest_raw.fragments[0..@beginning.latest.precision] == @ending.earliest_raw.fragments[0..@ending.earliest.precision]
        )       
        timeframe = "in #{@beginning.to_s.gsub("by ","")}"

      # Handle "on January 1, 2001" instead of "January 1, 2001 until January 1, 2001"
      elsif (
        @beginning && @ending && @beginning.precise? && @ending.precise? && botb == eote 
      )
        timeframe = "on #{beginning.to_s}"
      else
        timeframe = @beginning.to_s || ""
        unless ending.nil?
          timeframe += " until " + @ending.to_s.gsub("after", "at least").gsub("by","sometime before")
        end
      end
      if timeframe.empty?
        timeframe = nil 
      else
        timeframe.gsub!(/\s+/," ")
      end
      timeframe.strip! unless timeframe.nil?
      return timeframe
    end

    # Setter for the {#next_period}.  
    # Will also reset direct transfer to false.
    # @param p [Period] the period directly following this period
    # @return [void]
    def next_period=(p) 
      @next_period = p
      @direct_transfer = false
    end

    # Setter for the {#previous_period}.  
    # Will also reset the previous period's direct transfer to false.
    # @param p [Period] the period directly preceding this period
    # @return [void]
    def previous_period=(p)
      @previous_period = p
      @previous_period.direct_transfer = false if @previous_period
    end

    # Determine if this period is before the provided period
    # @param p [Period] a period to check
    # @return [Boolean] true if this period appears before the provided period
    def is_before? (p)
      current = self.next_period
      while !current.nil?
        return true if current == p
        current = current.next_period
      end
      return false
    end

    # Determine if this period is after the provided period
    # @param p [Period] a period to check
    # @return [Boolean] true if this period appears after the provided period
    def is_after? (p)
      current = self.previous_period
      while !current.nil?
        return true if current == p
        current = current.previous_period
      end
      return false
    end

    # An array of all the periods linked to this period.
    #
    # The returned array will be ordered earliest-to-latest.
    #
    # @return [Array<Period>]
    def siblings
      siblings = [self]
      current = self.previous_period
      while !current.nil?
        siblings.unshift(current)
        current = current.previous_period
      end
      current = self.next_period
      while !current.nil?
        siblings.push(current)
        current = current.next_period
      end
      return siblings
    end

    # Set this period to indicate a direct transfer to the next period.
    #
    # Will return nil if there is not a next period.
    #
    # @param b [Boolean]
    # @return [Boolan, Nil]
    def direct_transfer= (b)
      if @next_period.nil?
        @direct_transfer = nil
      else
        @direct_transfer = b.to_bool
      end
      #if @direct_transfer
        # if @ending && @next_period.beginning
        #   raise DateError, "Date Mismatch between #{@ending} and #{@next_period.beginning}" unless @ending == @next_period.beginning
        # elsif @ending && !@next_period.beginning
        #   @next_period.beginning = @ending
        # elsif @next_period.beginning && !@ending
        #   @ending = @next_period.beginning
        # end
      #end
    end

    # Was this record directly transferred to the following {Period}
    #@return [Boolean, Nil] True if it was transferred directly, false if it wasn't, Nil if is there is no following record.
    def direct_transfer
      @next_period.nil? ? nil : @direct_transfer
    end
    alias :direct_transfer? :direct_transfer
    

    # Was this record directly received from the preceding {Period}
    #@return [Boolean, Nil] True if it was received directly, false if it wasn't, Nil if is there is no preciding record.
    def was_directly_transferred
      @previous_period.nil? ? nil : @previous_period.direct_transfer
    end
    alias :was_directly_transferred? :was_directly_transferred

    # Set the associated party of the Period.
    # @todo Allow this to be a {Party}, not just a string.
    # @todo ALlow removing a party
    # @param _party [String] The name of the party
    # @return [Party] the party
    def party=(_party)
      @party = Party.new(_party) if _party
    end

    # Set the associated location of the Period.
    # @todo ALlow removing a location
    # @todo Allow this to be a {Location}, not just a string.
    # @param _party [String] The name of the location
    # @return [Location] the location
    def location=(_party)
      @location = Location.new(_party) if _party
    end

    ##### PROVENANCE AND FOOTNOTES ######
    
    # Does the record have a footnote
    # @return [Boolean] True if the record has a footnote
    def has_note?
      !(note.nil? || note.empty?)
    end

    # Generate a provenance record for this string.
    # @return [String] the provenance text for this period.
    def provenance
        new_name = @acquisition_method.nil? ? party.name_with_birth_death : @acquisition_method.attach_to_name(party.name_with_birth_death)
        record_cert = self.certainty ? nil : PERIOD_CERTAINTY_STRING
        val = [record_cert, [new_name, @location,time_string,stock_number].compact.join(", ")].compact.join(" ").gsub("  "," ")
        val[0] = val[0].upcase unless was_directly_transferred || val.blank?
        val = "(#{val})" unless primary_owner
        "" + val

    end
    alias :to_s :provenance
   

    # Does this period output provenance that matches the original text used to generate it.
    #
    # This will ignore differences in case and certainty.
    # @param strict [Boolean] don't account for acquisition form method changes, misplaced commas, or different spacing.
    # @return [Boolean] true if the {#original_text} matches the {#provenance}
    def parsable?(strict = false)
      if original_text.nil? 
        true
      else
        ot = original_text.clone
        p = provenance.clone
        Certainty::CertantyWords.each do |w| 
          ot.gsub!(w,"")
          p.gsub!(w,"")
        end

        basically_parsable = (ot.strip.downcase == p.strip.downcase)
        return true if basically_parsable
        return false if strict

        method = AcquisitionMethod.find(ot)
        return false if method.nil?

        method.forms.sort_by!{|t| t.length}.reverse.each do |f|
         new_ot = ot.gsub(/#{f}/i,"")
         if new_ot != ot
          ot = new_ot
          break
         end
        end
        ot = method.attach_to_name(ot)
        complicated_match = (ot.strip.downcase.gsub(" ","").gsub(",","") == p.strip.downcase.gsub(" ","").gsub(",",""))
        return complicated_match
      end
    end
    alias :parsable :parsable?

    # Set the beginning of the period to the value given.
    # @param (see TimeSpan.parse)
    # @raise (see TimeSpan.parse)
    # @return [TimeSpan]
    def beginning=(val)
      @beginning = TimeSpan.parse(val)
    end

    # The {TimeSpan} representing the starting of this period.
    #
    # This will return the raw timespan.
    # @see #botb, #eotb
    # @return [TimeSpan]
    def beginning
      @beginning
    end

    # Set the ending of the period to the value given.
    # @param (see TimeSpan.parse)
    # @raise (see TimeSpan.parse)
    # @return [TimeSpan]
    def ending=(b)
      @ending = TimeSpan.parse(b)
    end

    # The {TimeSpan} representing the completion of this period.
    # This will return the raw timespan.
    # @see #bote, #eote
    # @return [TimeSpan]
    def ending
      @ending
    end

    # The {Date} representing the earliest possible date for the start of this period.
    #
    # This is the last date by which you are certain the work was NOT owned by the relevant party.
    #
    # This best way to think about this date is it is the last date where you
    # know for sure that the period was NOT valid.  For example, if you know
    # that an artwork was owned by Jane in Feb. 2000, and you know that the artwork
    # was owned by Jill in March 2001, for the Jill's period of ownership the
    # {#botb} is Feb. 2000.
    # 
    # @return [Date]
    def botb 
      @beginning.earliest if @beginning
    end
    alias :begin_of_the_begin :botb


    # The {Date} representing the latest possible date for the start of this period.
    #
    # This is the first date by which you are certain the work was owned by the relevant party.
    #
    # This best way to think about this date is it is the first date where you
    # know for sure that the period WAS valid.  For example, if you know
    # that an artwork was owned by Jane in Feb. 2000, and you know that the artwork
    # was owned by Jill in March 2001, for the Jill's period of ownership the
    # {#eotb} is March 2001.  
    # 
    # @return [Date]
    def eotb 
      @beginning.latest if @beginning 
    end
    alias :end_of_the_begin :eotb

    # The {Date} representing the earliest possible date for the end of this period.
    #
    # This is the last date by which you are certain the work was owned by the relevant party.
    #
    # This best way to think about this date is it is the first date where you
    # know for sure that the period WAS valid.  For example, if you know
    # that an artwork was owned by Jane in Feb. 2000, and you know that the artwork
    # was owned by Jill in March 2001, for the Jane's period of ownership the
    # {#bote} is Feb. 2000.  
    # 
    # @return [Date]
    def bote 
      @ending.earliest if @ending
    end
    alias :begin_of_the_end :bote

    # The {Date} representing the latest possible date for the end of this period.
    #
    # This is the first date by which you are certain the work was NOT owned by the relevant party.
    #
    # This best way to think about this date is it is the first date where you
    # know for sure that the period WAS valid.  For example, if you know
    # that an artwork was owned by Jane in Feb. 2000, and you know that the artwork
    # was owned by Jill in March 2001, for the Jane's period of ownership the
    # {#eote} is March 2001.  
    # 
    # @return [Date]
    def eote 
      @ending.latest if @ending 
    end
    alias :end_of_the_end :eote

    # Is this period currently active
    #
    # This is used to determine if a period continues until the present day.
    # A period is defined as ongoing if there is a beginning, no ending, and no next period.
    #
    # @return [Boolean] 
    def is_ongoing?
      next_period.nil? && @ending.nil? && !@beginning.nil?
    end

    # The {TimeSpan} of the longest possible duration of this period
    #
    # @return [TimeSpan, Nil] 
    def max_timespan
      return nil unless (@beginning && @ending) || self.is_ongoing?
      if self.is_ongoing?
        TimeSpan.new(botb,Date.today)
      else
        TimeSpan.new(botb,eote)
      end
    end

    # Find the earliest possible date for this period
    #
    # This differs from {#botb} in that it will traverse the list backwards 
    # looking for a date.  This is to handle periods that are ordered, but without
    # any defined dates.  Will return nil if no date can be found.
    #
    # @return [Date, Nil] The earliest possible date for this period
    def earliest_possible
      return begin_of_the_begin if begin_of_the_begin
      d = party.birth if party && party.birth
      if previous_period
        n = previous_period.earliest_possible
        n = previous_period.begin_of_the_begin if previous_period.begin_of_the_begin
        n = previous_period.end_of_the_begin if previous_period.end_of_the_begin
        n = previous_period.begin_of_the_end if previous_period.begin_of_the_end
      end
      return n if n && !d 
      return d if d && !n
      return [n,d].max if n && d
      return nil
    end

    # Find the latest possible date for this period
    #
    # This differs from {#eote} in that it will traverse the list forwards 
    # looking for a date.  This is to handle periods that are ordered, but without
    # any defined dates.  Will return nil if no date can be found.  Will return today
    # if the period is ongoing.
    #
    # @return [Date, Nil] The latest possible date for this period
    def latest_possible
      return end_of_the_end if end_of_the_end
      return Date.today if is_ongoing?
      d =  party.death.latest if party && party.death
      if next_period
        n = next_period.latest_possible
        n = next_period.end_of_the_end if next_period.end_of_the_end
        n = next_period.begin_of_the_end if next_period.begin_of_the_end
        n = next_period.end_of_the_begin if next_period.end_of_the_begin
      end
      return n if n && !d 
      return d if d && !n
      return [n,d].min if n && d
      return Date.today
    end

    # Find the earliest definite date for this period
    #
    # @return [Date, Nil] The earliest definite date for this period
    def earliest_definite
      return eotb if eotb
      return bote if bote
      return nil
    end

# Find the latest definite date for this period
    #
    # @return [Date, Nil] The latest definite date for this period
    def latest_definite
     return Time.now.to_date if is_ongoing?
     return bote if bote
     return next_period.botb if direct_transfer? && next_period.beginning && next_period.beginning.same?
     return eotb if eotb
     return nil
    end
  end

  def Period.formatted_footnote(number,note)
    return "[#{number}] #{note}" if note
  end
end