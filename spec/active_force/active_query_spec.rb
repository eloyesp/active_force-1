require 'spec_helper'

describe ActiveForce::ActiveQuery do
  let(:sobject) do
    double("sobject", {
      table_name: "table_name",
      fields: [],
      mappings: mappings
    })
  end
  let(:mappings){ { id: "Id", field: "Field__c", other_field: "Other_Field" } }
  let(:client){ double("client") }
  let(:active_query){ described_class.new(sobject) }
  let(:api_result) do
    [
      {"Id" => "0000000000AAAAABBB"},
      {"Id" => "0000000000CCCCCDDD"}
    ]
  end


  before do
    allow(active_query).to receive(:sfdc_client).and_return client
    allow(active_query).to receive(:build).and_return Object.new
  end

  describe "to_a" do
    before do
      expect(client).to receive(:query).and_return(api_result)
    end

    it "should return an array of objects" do
      result = active_query.where("Text_Label = 'foo'").to_a
      expect(result).to be_a Array
    end

    it "should decorate the array of objects" do
      expect(sobject).to receive(:decorate)
      active_query.where("Text_Label = 'foo'").to_a
    end
  end

  describe "select only some field using mappings" do
    it "should return a query only with selected field" do
      active_query.select(:field)
      expect(active_query.to_s).to eq("SELECT Field__c FROM table_name")
    end
  end

  describe "condition mapping" do
    it "maps conditions for a .where" do
      active_query.where(field: 123)
      expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123)")
    end

    it 'transforms an array to a WHERE/IN clause' do
      active_query.where(field: ['foo', 'bar'])
      expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c IN ('foo','bar'))")
    end

    it "encloses the value in quotes if it's a string" do
      active_query.where field: "hello"
      expect(active_query.to_s).to end_with("(Field__c = 'hello')")
    end

    it "formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if it's a DateTime" do
      value = DateTime.now
      active_query.where(field: value)
      expect(active_query.to_s).to end_with("(Field__c = #{value.iso8601})")
    end

    it "formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if it's a Time" do
      value = Time.now
      active_query.where(field: value)
      expect(active_query.to_s).to end_with("(Field__c = #{value.iso8601})")
    end

    it "formats as YYYY-MM-DD and does not enclose in quotes if it's a Date" do
      value = Date.today
      active_query.where(field: value)
      expect(active_query.to_s).to end_with("(Field__c = #{value.iso8601})")
    end

    it "puts NULL when a field is set as nil" do
      active_query.where field: nil
      expect(active_query.to_s).to end_with("(Field__c = NULL)")
    end

    describe 'bind parameters' do
      let(:mappings) do
        super().merge({
          other_field: 'Other_Field__c',
          name: 'Name'
        })
      end

      it 'accepts bind parameters' do
        active_query.where('Field__c = ?', 123)
        expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123)")
      end

      it 'accepts nil bind parameters' do
        active_query.where('Field__c = ?', nil)
        expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = NULL)")
      end

      it 'accepts multiple bind parameters' do
        active_query.where('Field__c = ? AND Other_Field__c = ? AND Name = ?', 123, 321, 'Bob')
        expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123 AND Other_Field__c = 321 AND Name = 'Bob')")
      end

      it 'formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if value is a DateTime' do
        value = DateTime.now
        active_query.where('Field__c > ?', value)
        expect(active_query.to_s).to end_with("(Field__c > #{value.iso8601})")
      end

      it 'formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if value is a Time' do
        value = Time.now
        active_query.where('Field__c > ?', value)
        expect(active_query.to_s).to end_with("(Field__c > #{value.iso8601})")
      end

      it 'formats as YYYY-MM-DD and does not enclose in quotes if value is a Date' do
        value = Date.today
        active_query.where('Field__c > ?', value)
        expect(active_query.to_s).to end_with("(Field__c > #{value.iso8601})")
      end

      it 'complains when there given an incorrect number of bind parameters' do
        expect{
          active_query.where('Field__c = ? AND Other_Field__c = ? AND Name = ?', 123, 321)
        }.to raise_error(ActiveForce::PreparedStatementInvalid, 'wrong number of bind variables (2 for 3)')
      end

      context 'named bind parameters' do
        it 'accepts bind parameters' do
          active_query.where('Field__c = :field', field: 123)
          expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123)")
        end

        it 'accepts nil bind parameters' do
          active_query.where('Field__c = :field', field: nil)
          expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = NULL)")
        end

        it 'formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if value is a DateTime' do
          value = DateTime.now
          active_query.where('Field__c < :field', field: value)
          expect(active_query.to_s).to end_with("(Field__c < #{value.iso8601})")
        end

        it 'formats as YYYY-MM-DDThh:mm:ss-hh:mm and does not enclose in quotes if value is a Time' do
          value = Time.now
          active_query.where('Field__c < :field', field: value)
          expect(active_query.to_s).to end_with("(Field__c < #{value.iso8601})")
        end

        it 'formats as YYYY-MM-DD and does not enclose in quotes if value is a Date' do
          value = Date.today
          active_query.where('Field__c < :field', field: value)
          expect(active_query.to_s).to end_with("(Field__c < #{value.iso8601})")
        end

        it 'accepts multiple bind parameters' do
          active_query.where('Field__c = :field AND Other_Field__c = :other_field AND Name = :name', field: 123, other_field: 321, name: 'Bob')
          expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123 AND Other_Field__c = 321 AND Name = 'Bob')")
        end

        it 'accepts multiple bind parameters orderless' do
          active_query.where('Field__c = :field AND Other_Field__c = :other_field AND Name = :name', name: 'Bob', other_field: 321, field: 123)
          expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Field__c = 123 AND Other_Field__c = 321 AND Name = 'Bob')")
        end

        it 'complains when there given an incorrect number of bind parameters' do
          expect{
            active_query.where('Field__c = :field AND Other_Field__c = :other_field AND Name = :name', field: 123, other_field: 321)
          }.to raise_error(ActiveForce::PreparedStatementInvalid, 'missing value for :name in Field__c = :field AND Other_Field__c = :other_field AND Name = :name')
        end
      end
    end
  end

  describe '#where' do
    before do
      allow(client).to receive(:query).with("SELECT Id FROM table_name WHERE (Text_Label = 'foo')").and_return(api_result1)
      allow(client).to receive(:query).with("SELECT Id FROM table_name WHERE (Text_Label = 'foo') AND (Checkbox_Label = true)").and_return(api_result2)
    end
    let(:api_result1) do
      [
        {"Id" => "0000000000AAAAABBB"},
        {"Id" => "0000000000CCCCCDDD"},
        {"Id" => "0000000000EEEEEFFF"}
      ]
    end
    let(:api_result2) do
      [
        {"Id" => "0000000000EEEEEFFF"}
      ]
    end
    it 'allows method chaining' do
      result = active_query.where("Text_Label = 'foo'").where("Checkbox_Label = true")
      expect(result).to be_a described_class
    end

    context 'when calling `where` on an ActiveQuery object that already has records' do
      it 'returns a new ActiveQuery object' do
        first_active_query = active_query.where("Text_Label = 'foo'")
        first_active_query.inspect # so the query is executed
        second_active_query = first_active_query.where("Checkbox_Label = true")
        second_active_query.inspect
        expect(second_active_query).to be_a described_class
        expect(second_active_query).not_to eq first_active_query
      end
    end

  end

  describe "#find_by" do
    it "should query the client, with the SFDC field names and correctly enclosed values" do
      expect(client).to receive :query
      active_query.find_by field: 123
      expect(active_query.to_s).to eq "SELECT Id FROM table_name WHERE (Field__c = 123) LIMIT 1"
    end
  end

  describe '#find_by!' do
    it 'raises if record not found' do
      allow(client).to receive(:query).and_return(build_restforce_collection)
      expect { active_query.find_by!(field: 123) }
        .to raise_error(ActiveForce::RecordNotFound, "Couldn't find #{sobject.table_name} with {:field=>123}")
    end
  end

  describe '#find!' do
    let(:id) { 'test_id' }

    before do
      allow(client).to receive(:query).and_return(build_restforce_collection([{ 'Id' => id }]))
    end

    it 'queries for single record by given id' do
      active_query.find!(id)
      expect(client).to have_received(:query).with("SELECT Id FROM #{sobject.table_name} WHERE (Id = '#{id}') LIMIT 1")
    end

    context 'when record is found' do
      let(:record) { build_restforce_sobject(id: id) }

      before do
        allow(active_query).to receive(:build).and_return(record)
      end

      it 'returns the record' do
        expect(active_query.find!(id)).to eq(record)
      end
    end

    context 'when no record is found' do
      before do
        allow(client).to receive(:query).and_return(build_restforce_collection)
      end

      it 'raises RecordNotFound' do
        expect { active_query.find!(id) }
          .to raise_error(ActiveForce::RecordNotFound, "Couldn't find #{sobject.table_name} with id #{id}")
      end
    end
  end

  describe "responding as an enumerable" do
    before do
      expect(active_query).to receive(:to_a).and_return([])
    end

    it "should call to_a when receiving each" do
      active_query.each {}
    end

    it "should call to_a when receiving map" do
      active_query.map {}
    end
  end

  describe "prevent SOQL injection attacks" do
    let(:mappings){ { quote_field: "QuoteField", backslash_field: "Backslash_Field__c", number_field: "NumberField" } }
    let(:quote_input){ "' OR Id!=NULL OR Id='" }
    let(:backslash_input){ "\\" }
    let(:number_input){ 123 }
    let(:expected_query){ "SELECT Id FROM table_name WHERE (Backslash_Field__c = '\\\\' AND NumberField = 123 AND QuoteField = '\\' OR Id!=NULL OR Id=\\'')" }

    it 'escapes quotes and backslashes in bind parameters' do
      active_query.where('Backslash_Field__c = :backslash_field AND NumberField = :number_field AND QuoteField = :quote_field', number_field: number_input, backslash_field: backslash_input, quote_field: quote_input)
      expect(active_query.to_s).to eq(expected_query)
    end

    it 'escapes quotes and backslashes in named bind parameters' do
      active_query.where('Backslash_Field__c = ? AND NumberField = ? AND QuoteField = ?', backslash_input, number_input, quote_input)
      expect(active_query.to_s).to eq(expected_query)
    end

    it 'escapes quotes and backslashes in hash conditions' do
      active_query.where(backslash_field: backslash_input, number_field: number_input, quote_field: quote_input)
      expect(active_query.to_s).to eq("SELECT Id FROM table_name WHERE (Backslash_Field__c = '\\\\') AND (NumberField = 123) AND (QuoteField = '\\' OR Id!=NULL OR Id=\\'')")
    end
  end

  describe '#none' do
    it 'returns a query with a where clause that is impossible to satisfy' do
      expect(active_query.none.to_s).to eq "SELECT Id FROM table_name WHERE (Id = '111111111111111111') AND (Id = '000000000000000000')"
    end

    it 'does not query the API' do
      expect(client).to_not receive :query
      active_query.none.to_a
    end
  end

  describe '#loaded?' do
    subject { active_query.loaded? }

    before do
      active_query.instance_variable_set(:@records, records)
    end

    context 'when there are records loaded in memory' do
      let(:records) { nil }

      it { is_expected.to be_falsey }
    end

    context 'when there are records loaded in memory' do
      let(:records) { [build_restforce_sobject(id: 1)] }

      it { is_expected.to be_truthy }
    end
  end
end
