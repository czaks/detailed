require "active_record/associations/association_scope.rb"

module Detailed
  def self.included (mod)
    class << mod
      attr_accessor :subclasses
      
      def add_subclass(sc)
        @subclasses ||= []
        @subclasses << sc
        
        class_eval do
          has_one :"details_of_#{sc.name.tableize}", class_name: "#{self.name}#{sc.name}Detail", foreign_key: "#{sc.name.tableize.singularize}_id" #, inverse_of: "#{sc.name.tableize}"
        end
      end
      
      def all_with_details
        @subclasses ||= []
        @subclasses.inject(self.unscoped) { |a,b| a.includes(:"details_of_#{b.name.tableize}") }
      end
      
      def request_details
        self.superclass.add_subclass(self)
        
	class_eval do
	  accepts_nested_attributes_for :"details_of_#{self.name.tableize}"
          default_scope do
            eager_load :"details_of_#{self.name.tableize}"
          end
          
          alias :details  :"details_of_#{self.name.tableize}"
          alias :details= :"details_of_#{self.name.tableize}="
	  
	  after_initialize do
	    self.details ||= "#{self.class.superclass.name}#{self.class.name}Detail".constantize.new if self.new_record?
	  end
	  
	  alias :__old_method_missing :method_missing
	  alias :__old_respond_to? :respond_to?
	  alias :__old_methods :methods
          alias :__old_write_attribute :write_attribute
          alias :__old_read_attribute :read_attribute
          alias :__old_query_attribute :query_attribute
          
          def query_attribute a
            __old_query_attribute(a) or (details and details.send(:query_attribute, a))
          end
          
          def read_attribute a
            __old_read_attribute(a) or (details and details.send(:read_attribute, a))
          end
          
          def write_attribute a, b
            __old_write_attribute a, b
          rescue ActiveModel::MissingAttributeError => e
            begin
              details.send :write_attribute, a, b
            rescue ActiveModel::MissingAttributeError
              raise e
            end
          end

	  def method_missing a, *b
            __old_method_missing a, *b
          rescue NoMethodError, NameError => e
	    begin
              details.send a, *b
            rescue NoMethodError, NameError
              raise e
            end
	  end
	  
	  def respond_to? *a
	    __old_respond_to?(*a) or (details ? details.respond_to?(*a) : false)
	  end
	  
	  def methods *a
	    __old_methods(*a) | (details ? details.methods(*a) : [])
	  end
	end
      end
    end
  end
  
  module AssociationScope
    def self.included cl
      cl.class_eval do
        def maybe_split(table, field, reflection)
          if field.match /\./
            table, field = field.split(/\./, 2)
            table = alias_tracker.aliased_table_for(table, table_alias_for(reflection, self.reflection != reflection))
          end
                    
          [table, field]
        end
        
        # Extend add_constraints support for "table.column" notation
        #
        # This gives us power to do eg.:
        #  has_many :frames, foreign_key: "project_frame_details.glass_id"        
        def add_constraints(scope)
          tables = construct_tables
          
          chain.each_with_index do |reflection, i|
            table, foreign_table = tables.shift, tables.first
            
            if reflection.source_macro == :has_and_belongs_to_many
              join_table = tables.shift
                           
              scope = scope.joins(join(
                                       join_table,
                                       table[association_primary_key].
                                      eq(join_table[association_foreign_key])
                                      ))
              
              table, foreign_table = join_table, tables.first
            end
          
            if reflection.source_macro == :belongs_to
              if reflection.options[:polymorphic]
                key = reflection.association_primary_key(self.klass)
              else
                key = reflection.association_primary_key
              end
              
              foreign_key = reflection.foreign_key
            else
              key         = reflection.foreign_key
              foreign_key = reflection.active_record_primary_key
            end
            
            # this is our addition
            table, key = maybe_split(table, key, reflection)
            foreign_table, foreign_key = maybe_split(foreign_table, foreign_key, reflection)
            # end
            
            if reflection == chain.last              
              bind_val = bind scope, table.table_name, key.to_s, owner[foreign_key]
              scope    = scope.where(table[key].eq(bind_val))
              
              if reflection.type
                value    = owner.class.base_class.name
                bind_val = bind scope, table.table_name, reflection.type.to_s, value
                scope    = scope.where(table[reflection.type].eq(bind_val))
              end
            else
              constraint = table[key].eq(foreign_table[foreign_key])
              
              if reflection.type
                type = chain[i + 1].klass.base_class.name
                constraint = constraint.and(table[reflection.type].eq(type))
              end
              
              scope = scope.joins(join(foreign_table, constraint))
            end
            
            # Exclude the scope of the association itself, because that
            # was already merged in the #scope method.
            scope_chain[i].each do |scope_chain_item|
              klass = i == 0 ? self.klass : reflection.klass
              item  = eval_scope(klass, scope_chain_item)
              
              if scope_chain_item == self.reflection.scope
                scope.merge! item.except(:where, :includes)
              end
              
              scope.includes! item.includes_values
              scope.where_values += item.where_values
              scope.order_values |= item.order_values
            end
          end
          
          scope
        end
      end
    end
  end
end


class ActiveRecord::Associations::AssociationScope
  include Detailed::AssociationScope
end