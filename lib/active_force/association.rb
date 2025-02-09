require 'active_force/association/association'
require 'active_force/association/eager_load_projection_builder'
require 'active_force/association/relation_model_builder'
require 'active_force/association/has_many_association'
require 'active_force/association/has_one_association'
require 'active_force/association/belongs_to_association'

module ActiveForce
  module Association
    def associations
      @associations ||= {}
    end

    def find_association name
      associations[name.to_sym]
    end

    def has_many relation_name, options = {}
      associations[relation_name] = HasManyAssociation.new(self, relation_name, options)
    end

    def has_one relation_name, options = {}
      associations[relation_name] = HasOneAssociation.new(self, relation_name, options)
    end

    def belongs_to relation_name, options = {}
      associations[relation_name] = BelongsToAssociation.new(self, relation_name, options)
    end
  end
end
