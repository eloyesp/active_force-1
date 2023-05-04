module ActiveForce
  module Association
    class EagerLoadProjectionBuilder
      class << self
        def build(association, parent_associations)
          new(association, parent_associations).projections
        end
      end

      attr_reader :association, :parent_associations

      def initialize(association, parent_associations)
        @association = association
        @parent_associations = parent_associations
      end

      def projections
        klass = association.class.name.split('::').last
        builder_class = ActiveForce::Association.const_get "#{klass}ProjectionBuilder"
        builder_class.new(association, parent_associations).projections
      rescue NameError
        raise "Don't know how to build projections for #{klass}"
      end
    end

    class AbstractProjectionBuilder
      attr_reader :association, :parent_associations

      def initialize(association, parent_associations)
        @association = association
        @parent_associations = parent_associations
      end

      def projections
        raise "Must define #{self.class.name}#projections"
      end

      def association_chain
        @association_chain ||= parent_associations + [association]
      end

      def sf_relation_name
        association_chain.map(&:sfdc_association_field).join('.')
      end
    end

    class HasManyAssociationProjectionBuilder < AbstractProjectionBuilder
      ###
      # Use ActiveForce::Query to build a subquery for the SFDC
      # relationship name. Per SFDC convention, the name needs
      # to be pluralized
      def projections
        relationship_name = sf_relation_name
        query = Query.new relationship_name
        query.fields association.relation_model.fields

        ["(#{query.to_s})"]
      end
    end

    class HasOneAssociationProjectionBuilder < AbstractProjectionBuilder
      def projections
        query = Query.new sf_relation_name
        query.fields association.relation_model.fields
        ["(#{query.to_s})"]
      end
    end

    class BelongsToAssociationProjectionBuilder < AbstractProjectionBuilder
      def projections
        association.relation_model.fields.map do |field|
          "#{ sf_relation_name }.#{ field }"
        end
      end
    end
  end
end
