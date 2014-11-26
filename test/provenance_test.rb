require_relative "test_helper.rb"

describe Provenance do
  
  it "extracts text into an Timeline" do
    Provenance.extract("sample text").must_be_kind_of Timeline
  end

  it "handles nothingness well" do
    p = Provenance.extract(nil)
    p.must_be_kind_of Timeline
    p.count.must_equal 0
  end

  it "handles crlfs" do
    text = "sample text
    second line"
    p = Provenance.extract(text)
    p.must_be_kind_of Timeline
    p.count.must_equal 1
  end

  describe "stock numbers" do
    it "finds stock numbers" do
      timeline = Provenance.extract("Sold to David Newbury, stock no. 55512")
      timeline[0].to_h[:stock_number].must_equal "stock no. 55512"
    end

    it "finds numbers" do
      timeline = Provenance.extract("Sold to David Newbury no. 55512")
      timeline[0].to_h[:stock_number].must_equal "no. 55512"
    end
  end

  describe "death original text" do
    it "has the proper text for death notes" do
      text = 'David Newbury (d. 1935), Pittsburgh'
      timeline = Provenance.extract(text)
      record = timeline[0].to_h
      record[:original_text].must_equal text
      record[:provenance].must_equal "David Newbury [-1935], Pittsburgh"
      record[:death].must_equal Date.new(1935).latest
    end
  end

  describe "dealer parentheticals" do
    it "extracts primary ownership" do
      timeline = Provenance.extract "David Newbury, 1995"
      timeline[0].primary_owner.must_equal true
      timeline[0].to_h[:party].must_equal "David Newbury"
      timeline[0].beginning.must_equal TimeSpan.parse("1995")
      timeline[0].provenance.must_equal "David Newbury, 1995"
      timeline[0].to_h[:primary_owner].must_equal true
      timeline[0].to_h[:original_text].must_equal "David Newbury, 1995"
   end
    it "extracts non-primary ownership" do
      timeline = Provenance.extract "(David Newbury, 1995)."
      timeline[0].primary_owner.must_equal false
      timeline[0].to_h[:party].must_equal "David Newbury"
      timeline[0].beginning.must_equal TimeSpan.parse("1995")
      timeline[0].provenance.must_equal "(David Newbury, 1995)"
      timeline[0].to_h[:primary_owner].must_equal false
      timeline[0].to_h[:original_text].must_equal "(David Newbury, 1995)"
    end
    it "works with JSON" do
      timeline = Provenance.extract "(David Newbury, 1995)."
      timeline2 = Provenance.from_json(timeline.to_json)
      timeline2[0].provenance.must_equal "(David Newbury, 1995)"
    end
    it "works with names that begin with parenthesis" do
      timeline = Provenance.extract "(David) Newbury, 1995."
      timeline[0].primary_owner.must_equal true
      timeline[0].to_h[:party].must_equal "(David) Newbury"
      timeline[0].beginning.must_equal TimeSpan.parse("1995")
      timeline[0].provenance.must_equal "(David) Newbury, 1995"
    end
  end

  describe "acq. method extraction" do

    it "does not remove anything if it's not a method" do
      timeline = Provenance.extract "David Newbury, 1995"
      timeline[0].acquisition_method.must_be_nil
    end

    it "removes standard prefixes" do
      timeline = Provenance.extract "Sold to David Newbury"
      timeline[0].acquisition_method.must_be_instance_of AcquisitionMethod
      timeline[0].acquisition_method.must_equal AcquisitionMethod::SALE

      timeline[0].to_h[:party].must_equal "David Newbury"

    end

    it "removes standard suffixes" do
      timeline = Provenance.extract "David Newbury, by exchange"
      timeline[0].acquisition_method.must_be_instance_of AcquisitionMethod
      timeline[0].acquisition_method.must_equal AcquisitionMethod::EXCHANGE
      timeline[0].to_h[:party].must_equal "David Newbury"
    end

    it "doesn't bork on donation" do
      timeline = Provenance.extract "Donated to David Newbury"
      timeline[0].acquisition_method.must_equal AcquisitionMethod::GIFT
      timeline[0].parsable?.must_equal true
    end

    it "doesn't bork on sold at auction" do
      timeline = Provenance.extract "sold at auction to David Newbury"
      timeline[0].acquisition_method.must_equal AcquisitionMethod::FOR_SALE
      timeline[0].parsable?.must_equal true
    end

    it "doesn't bork on sold at" do
      timeline = Provenance.extract "sold at David Newbury"
      timeline[0].acquisition_method.must_equal AcquisitionMethod::FOR_SALE
      timeline[0].parsable?.must_equal true
    end

    it "doesn't bork on by descent" do
      timeline = Provenance.extract "David Newbury, by descent"
      timeline[0].acquisition_method.must_equal AcquisitionMethod::BY_DESCENT
      timeline[0].parsable?.must_equal true
    end

    it "doesn't bork on by descent prefixed" do
      timeline = Provenance.extract "by descent to David Newbury"
      timeline[0].acquisition_method.must_equal AcquisitionMethod::BY_DESCENT
      timeline[0].parsable?.must_equal true
    end

  end

  describe "Record Certainty" do
    it "works with probably" do
      timeline = Provenance.extract  "Probably maybe."
      timeline[0].certain?.must_equal false
    end
    it "doesn't change text" do
      timeline = Provenance.extract  "I am certain."
      timeline[0].certain?.must_equal true
    end
    it "works with likely" do
      timeline = Provenance.extract  "Likely David, Pittsburgh."
      timeline[0].certain?.must_equal false
      timeline[0].party.must_equal Party.new("David")
    end
  end


  describe "Extraction" do
    let (:no_note) {"I do not have a note"}
    let (:note) {"I have a footnote [1]. 1. I am the note."}
    let (:other_note) {"I have a footnote [1]. NOTES: 1. I am the note."}
 
    it "does not find notes if they don't exist" do
      timeline = Provenance.extract (no_note)
      timeline[0].to_h[:provenance].must_equal no_note
      timeline[0].to_h[:footnote].must_be_empty
    end

    it "will find notes with periods" do
      timeline = Provenance.extract (note)
      timeline[0].to_h[:provenance].must_equal 'I have a footnote'
      timeline[0].to_h[:footnote].must_include 'I am the note.'
    end
    
    it "will find notes in note blocks" do
      timeline = Provenance.extract (other_note)
      timeline[0].to_h[:provenance].must_equal 'I have a footnote'
      timeline[0].to_h[:footnote].must_include 'I am the note.'
    end
  end

  describe "Period Substitution" do
    it "does not substitute periods for records" do
      timeline = Provenance.extract "I am a sentence.  I am another sentence."
      timeline.count.must_equal 2
    end

    it "does not assume that abbreviations are sentences" do
      timeline = Provenance.extract "Mr. David was here.  I am another sentence."
      timeline.count.must_equal 2
    end

    it "handles Initials" do
      timeline = Provenance.extract("Mr. David N. was here.  I am another sentence.")
      timeline.count.must_equal 2
    end

    it "handles initial Initials" do
      timeline = Provenance.extract("G. David was here.  I am another sentence.")
      timeline.count.must_equal 2
    end

    it "handles circa dates" do
      timeline = Provenance.extract "Mr. and Mrs. James L. Winokur, Pittsburgh, circa 1965; gift to museum, 1968"
      timeline.count.must_equal 2
      timeline[0].botb.must_equal Date.new(1965)
      timeline[0].eotb.must_equal Date.new(1965).latest
      timeline[0].botb.certainty.must_equal false
      timeline[0].eotb.certainty.must_equal false
      timeline[0].time_string.must_equal "1965?"
      timeline[0].party.name.must_equal "Mr. and Mrs. James L. Winokur"
      timeline[0].location.name.must_equal "Pittsburgh"
    end
    it "handles c. dates" do
      timeline = Provenance.extract "Mr. and Mrs. James L. Winokur, Pittsburgh, c. 1965; gift to museum, 1968"
      timeline.count.must_equal 2
      timeline[0].botb.must_equal Date.new(1965)
      timeline[0].eotb.must_equal Date.new(1965).latest
      timeline[0].botb.certainty.must_equal false
      timeline[0].eotb.certainty.must_equal false
      timeline[0].time_string.must_equal "1965?"
      timeline[0].party.name.must_equal "Mr. and Mrs. James L. Winokur"
      timeline[0].location.name.must_equal "Pittsburgh"
    end
    it "handles ca. dates" do
      timeline = Provenance.extract "Mr. and Mrs. James L. Winokur, Pittsburgh, ca. 1965; gift to museum, 1968"
      timeline.count.must_equal 2
      timeline[0].botb.must_equal Date.new(1965)
      timeline[0].eotb.must_equal Date.new(1965).latest
      timeline[0].botb.certainty.must_equal false
      timeline[0].eotb.certainty.must_equal false
      timeline[0].time_string.must_equal "1965?"
      timeline[0].party.name.must_equal "Mr. and Mrs. James L. Winokur"
      timeline[0].location.name.must_equal "Pittsburgh"
    end
    it "handles century dates" do
      timeline = Provenance.extract "Moses, Egypt, until the 7th Century; gift to museum, 1968"
      timeline.count.must_equal 2
      timeline[0].bote.must_equal Date.new(601)
      timeline[0].eote.must_equal Date.new(700).latest
      timeline[0].time_string.must_equal "until the 7th Century"
      timeline[0].party.name.must_equal "Moses"
      timeline[0].location.name.must_equal "Egypt"
    end
  end

  describe "Birth and Death Extraction" do
    it "doesn't find dates where there aren't any" do
      timeline = Provenance.extract("David, Pittsburgh, PA")
      timeline[0].to_h[:birth].must_be_nil
      timeline[0].to_h[:death].must_be_nil
      timeline[0].to_h[:party].must_equal "David"
      timeline[0].to_h[:location].must_equal "Pittsburgh, PA"  
    end

    it "finds dates" do
      timeline = Provenance.extract("David [1880-1980], Pittsburgh, PA")
      timeline[0].to_h[:birth].must_equal Date.new 1880
      timeline[0].to_h[:birth_certainty].must_equal true
      timeline[0].to_h[:death].must_equal  Date.new(1980).latest
      timeline[0].to_h[:death_certainty].must_equal true
      timeline[0].to_h[:party].must_equal "David"
      timeline[0].to_h[:location].must_equal "Pittsburgh, PA"  
    end
    it "finds death dates" do
      timeline = Provenance.extract("David (d. 1980), Pittsburgh, PA")
      timeline[0].to_h[:death].must_equal  Date.new(1980).latest
      timeline[0].to_h[:death_certainty].must_equal true
      timeline[0].to_h[:birth].must_be_nil
      timeline[0].to_h[:party].must_equal "David"
      timeline[0].to_h[:location].must_equal "Pittsburgh, PA" 
      timeline.count.must_equal 1
    end
    it "finds uncertain death dates" do
      timeline = Provenance.extract("David (d. 1980?), Pittsburgh, PA")
      timeline[0].to_h[:death].must_equal  Date.new(1980).latest
      timeline[0].to_h[:death_certainty].must_equal false
    end
    it "finds birth dates" do
      timeline = Provenance.extract("David (b. 1980), Pittsburgh, PA")
      timeline[0].to_h[:birth].must_equal  Date.new 1980
      timeline[0].to_h[:birth_certainty].must_equal true
      timeline[0].to_h[:death].must_be_nil
      timeline[0].to_h[:party].must_equal "David"
      timeline[0].to_h[:location].must_equal "Pittsburgh, PA" 
      timeline.count.must_equal 1
    end
    it "finds births with people who haven't died" do
      timeline = Provenance.extract("David (1980-), Pittsburgh, PA")
      timeline[0].to_h[:birth].must_equal  Date.new 1980
      timeline[0].to_h[:birth_certainty].must_equal true
      timeline[0].to_h[:death].must_be_nil
      timeline[0].to_h[:party].must_equal "David"
      timeline[0].to_h[:location].must_equal "Pittsburgh, PA"  
    end
    it "finds deaths with people who don't have birthdates" do
      timeline = Provenance.extract("David (-1980), Pittsburgh, PA")
      timeline[0].to_h[:birth].must_be_nil
      timeline[0].to_h[:death].must_equal Date.new(1980).latest
      timeline[0].to_h[:death_certainty].must_equal true
      timeline[0].to_h[:party].must_equal "David"
      timeline[0].to_h[:location].must_equal "Pittsburgh, PA"  
    end

    it "handles questionable birth dates" do
      timeline = Provenance.extract("David [1880?-1980?], Pittsburgh, PA")
      timeline[0].to_h[:birth].must_equal Date.new 1880
      timeline[0].to_h[:birth_certainty].must_equal false
      timeline[0].to_h[:death].must_equal Date.new(1980).latest
      timeline[0].to_h[:death_certainty].must_equal false
      timeline[0].to_h[:party].must_equal "David"
      timeline[0].to_h[:location].must_equal "Pittsburgh, PA"  
    end
  end

  describe "Name and location" do
    it "splits name and location" do
      timeline = Provenance.extract("David, Pittsburgh")
      timeline[0].to_h[:party].must_equal "David"
      timeline[0].to_h[:location].must_equal "Pittsburgh"
    end
    it "assigns multiple commas to location" do
      timeline = Provenance.extract("David, Pittsburgh, PA")
      timeline[0].to_h[:party].must_equal "David"
      timeline[0].to_h[:location].must_equal "Pittsburgh, PA"
    end
    it "handles no location" do
      timeline = Provenance.extract("David Newbury")
      timeline[0].to_h[:party].must_equal "David Newbury"
      timeline[0].to_h[:location].must_be_nil
    end
    it "handles Jrs" do
      timeline = Provenance.extract("David, Jr., Pittsburgh")
      timeline[0].to_h[:party].must_equal "David, Jr."
      timeline[0].to_h[:location].must_equal "Pittsburgh"
    end  
    it "handles Countesses" do
      timeline = Provenance.extract("David, Countess of Northbrook, Pittsburgh")
      timeline[0].to_h[:party].must_equal "David, Countess of Northbrook"
      timeline[0].to_h[:location].must_equal "Pittsburgh"
    end 
    it "handles Srs" do
      timeline = Provenance.extract("David, Sr., Pittsburgh")
      timeline[0].to_h[:party].must_equal "David, Sr."
      timeline[0].to_h[:location].must_equal "Pittsburgh"
    end
    it "handles Sgt." do
      timeline = Provenance.extract("Sgt. David, Pittsburgh")
      timeline[0].to_h[:party].must_equal "Sgt. David"
      timeline[0].to_h[:location].must_equal "Pittsburgh"
    end   
    it "handles Col." do
      timeline = Provenance.extract("Col. David Newbury, Pittsburgh")
      timeline[0].to_h[:party].must_equal "Col. David Newbury"
      timeline[0].to_h[:location].must_equal "Pittsburgh"
    end      
  end
 
  describe "Line Splitting" do
    it "splits sentences" do
      Provenance.extract("I am a sentence.  I am another sentence.").count.must_equal 2
    end
    it "splits sentences with semicolons" do
      Provenance.extract("I am a sentence; I am another sentence.").count.must_equal 2
    end
    it "splits sentences with abbrev." do
      Provenance.extract("Dr. Mario says I am a sentence. I am another sentence.").count.must_equal 2
    end
    it "does split on embedded abbrev" do
      Provenance.extract("Dr. Mario says I am a loca. I am another sentence.").count.must_equal 2
    end
    it "splits sentences with states" do
      val = Provenance.extract("Mr. and Mrs. Alvin P. Fenderson, Paoli, Pa., by 1947;  I am another sentence.")
      val.count.must_equal 2
      val[0].location.name.must_equal "Paoli, PA"
    end
    it 'handles things with only an aquisition method' do
      val = Provenance.extract "Louis Majorelle, Villa Jika, Nancy; by descent; Charles Janoray, New York, LLC in 2007"
      val.count.must_equal 3
      val[1].party.name.must_equal ""
      val[1].acquisition_method.must_equal AcquisitionMethod::BY_DESCENT
      val.to_json.must_be_instance_of String
    end
   end
   describe "Text Transformations" do
    it "handles his gift" do
      val = Provenance.extract  "Kenneth Seaver, Pittsburgh, PA; his gift to Museum, January 1949."
      val.count.must_equal 2
      val[1].party.name.must_equal "Museum"
      val[1].acquisition_method.must_equal AcquisitionMethod::GIFT
    end
    it "uses proper synonyms for painted by" do
      val = Provenance.extract  "painted for the chapel of Girolamo Ferretti, S. Francesco delle Scale, Ancona"
      val.count.must_equal 1
      val[0].acquisition_method.must_equal AcquisitionMethod::COMMISSION
      val[0].party.name.must_equal "the chapel of Girolamo Ferretti"
      val[0].provenance.must_equal "Commissioned by the chapel of Girolamo Ferretti, S. Francesco delle Scale, Ancona"     
    end
    it "detects Luht numbers" do
      types = ["(Lugt, suppl., 2451a)",
      "(Lugt Suppl. 1808h)",
      "(L., Supplément, 633b)",
      "(Lugt 690)",
      "(L.1383)",
      "(L.633b)",
      "(Lugt 1606 and 2398)",
      "(Lugt 624-626)",
      "(Lugt suppl. 2187a)",
      "(L. 2215b)",
      "(Lugt. 657)"]
      nums = ["2451a","1808h","633b","690","1383","633b","1606","2398","624","626","2187a","2215b","657"]
      types.each do |t|
        val = Provenance.extract  "Kenneth Seaver, Pittsburgh, PA #{t}; gift to Museum, January 1949."
        val.count.must_equal 2
        val[0].party.name.must_equal "Kenneth Seaver"
        val[1].party.name.must_equal "Museum"
        val[0].stock_number.split(" ").each do |sn|
          nums.collect{|n| "(L.#{n})"}.must_include sn
        end
      end
    end
  end
end