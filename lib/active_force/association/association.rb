module ActiveForce
  module Association
    class Association
      extend Forwardable
      def_delegators :relation_model, :build

      attr_accessor :options, :relation_name

      def initialize parent, relation_name, options = {}
        @parent        = parent
        @relation_name = relation_name
        @options       = options
        define_relation_method
        define_assignment_method
      end

      def relation_model
        (options[:model] || relation_name.to_s.singularize.camelcase).to_s.constantize
      end

      def foreign_key
        options[:foreign_key] || default_foreign_key
      end

      def relationship_name
        options[:relationship_name] || relation_model.to_s.constantize.table_name
      end

      ###
      # Does this association's relation_model represent
      # +sfdc_table_name+? Examples of +sfdc_table_name+
      # could be 'Quota__r' or 'Account'.
      def represents_sfdc_table?(sfdc_table_name)
        name = sfdc_table_name.sub(/__r\z/, '').singularize
        relationship_name.sub(/__c\z|__r\z/, '') == name
      end

      def sfdc_association_field
        relationship_name.gsub /__c\z/, '__r'
      end

      def load_target(owner)
        if loadable?(owner)
          target(owner)
        else
          target_when_unloadable
        end
      end

      private

      attr_reader :parent

      def loadable?(owner)
        owner&.persisted?
      end

      def target(_owner)
        raise NoMethodError, 'target must be implemented'
      end

      def target_when_unloadable
        nil
      end

      def define_relation_method
        association = self
        method_name = relation_name
        parent.send(:define_method, method_name) do
          association_cache.fetch(method_name) { association_cache[method_name] = association.load_target(self) }
        end
      end

      def define_assignment_method
        raise NoMethodError, 'define_assignment_method must be implemented'
      end

      def infer_foreign_key_from_model(model)
        name = model.custom_table? ? model.name : model.table_name
        name.foreign_key.to_sym
      end

      def apply_scope(query, owner)
        return query unless (scope = options[:scoped_as])

        if scope.arity.positive?
          query.instance_exec(owner, &scope)
        else
          query.instance_exec(&scope)
        end
      end
    end
  end
end
