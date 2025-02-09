require 'active_support/all'
require 'active_force/query'
require 'forwardable'

module ActiveForce
  class PreparedStatementInvalid < ArgumentError; end

  class RecordNotFound < StandardError
    attr_reader :table_name, :conditions

    def initialize(message = nil, table_name = nil, conditions = nil)
      @table_name = table_name
      @conditions = conditions

      super(message)
    end
  end

  class ActiveQuery < Query
    extend Forwardable

    attr_reader :sobject, :association_mapping

    def_delegators :sobject, :sfdc_client, :build, :table_name, :mappings
    def_delegators :to_a, :each, :map, :inspect, :pluck, :each_with_object

    def initialize sobject
      @sobject = sobject
      @association_mapping = {}
      super table_name
      fields sobject.fields
    end

    def to_a
      @decorated_records ||= sobject.try(:decorate, records) || records
    end

    private def records
      @records ||= result.to_a.map { |mash| build mash, association_mapping }
    end

    alias_method :all, :to_a

    def count
      super
      sfdc_client.query(to_s).first.expr0
    end

    def sum field
      super(mappings[field])
      sfdc_client.query(to_s).first.expr0
    end

    def limit limit
      super
      limit == 1 ? to_a.first : self
    end

    def not args=nil, *rest
      return self if args.nil?
      super build_condition args, rest
      self
    end

    def where args=nil, *rest
      return self if args.nil?
      return clone_self_and_clear_cache.where(args, *rest) if @decorated_records.present?
      super build_condition args, rest
      self
    end

    def select *fields
      fields.map! { |field| mappings[field] }
      super *fields
    end

    def find!(id)
      result = find(id)
      raise RecordNotFound.new("Couldn't find #{table_name} with id #{id}", table_name, id: id) if result.nil?

      result
    end

    def find_by conditions
      where(conditions).limit 1
    end

    def find_by!(conditions)
      result = find_by(conditions)
      raise RecordNotFound.new("Couldn't find #{table_name} with #{conditions}", table_name, conditions) if result.nil?

      result
    end

    def includes(*relations)
      relations.each do |relation|
        association = sobject.associations[relation]
        fields Association::EagerLoadProjectionBuilder.build association
        # downcase the key and downcase when we do the comparison so we don't do any more crazy string manipulation
        association_mapping[association.sfdc_association_field.downcase] = association.relation_name
      end
      self
    end

    def none
      @records = []
      where(id: '1'*18).where(id: '0'*18)
    end

    def loaded?
      !@records.nil?
    end

    private

    def build_condition(args, other=[])
      case args
      when String, Array
        build_condition_from_array other.empty? ? args : ([args] + other)
      when Hash
        build_conditions_from_hash args
      else
        args
      end
    end

    def build_condition_from_array(ary)
      statement, *bind_parameters = ary
      return statement if bind_parameters.empty?
      if bind_parameters.first.is_a? Hash
        replace_named_bind_parameters statement, bind_parameters.first
      else
        replace_bind_parameters statement, bind_parameters
      end
    end

    def replace_named_bind_parameters(statement, bind_parameters)
      statement.gsub(/(:?):([a-zA-Z]\w*)/) do
        key = $2.to_sym
        if bind_parameters.has_key? key
          enclose_value bind_parameters[key]
        else
          raise PreparedStatementInvalid, "missing value for :#{key} in #{statement}"
        end
      end
    end

    def replace_bind_parameters(statement, values)
      raise_if_bind_arity_mismatch statement.count('?'), values.size
      bound = values.dup
      statement.gsub('?') do
        enclose_value bound.shift
      end
    end

    def raise_if_bind_arity_mismatch(expected_var_count, actual_var_count)
      if expected_var_count != actual_var_count
        raise PreparedStatementInvalid, "wrong number of bind variables (#{actual_var_count} for #{expected_var_count})"
      end
    end

    def build_conditions_from_hash(hash)
      hash.map do |key, value|
        applicable_predicate mappings[key], value
      end
    end

    def applicable_predicate(attribute, value)
      if value.is_a? Array
        in_predicate attribute, value
      else
        eq_predicate attribute, value
      end
    end

    def in_predicate(attribute, values)
      escaped_values = values.map &method(:enclose_value)
      "#{attribute} IN (#{escaped_values.join(',')})"
    end

    def eq_predicate(attribute, value)
      "#{attribute} = #{enclose_value value}"
    end

    def enclose_value value
      case value
      when String
        quote_string(value)
      when NilClass
        'NULL'
      when Time
        value.iso8601
      else
        value.to_s
      end
    end

    def quote_string(s)
      "'#{s.gsub(/(['\\])/, '\\\\\\1')}'"
    end

    def result
      sfdc_client.query(self.to_s)
    end

    def clone_self_and_clear_cache
      new_query = self.clone
      new_query.instance_variable_set(:@decorated_records, nil)
      new_query.instance_variable_set(:@records, nil)
      new_query
    end
  end
end
