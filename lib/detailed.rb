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
        @subclasses.inject(self.all) { |a,b| a.includes(:"details_of_#{b.name.tableize}") }
      end
      
      def request_details
        self.superclass.add_subclass(self)
        
	class_eval do
	  #has_one :details, class_name: "#{self.superclass.name}#{self.name}Detail", dependent: :destroy
	  accepts_nested_attributes_for :"details_of_#{self.name.tableize}"
	  #default_scope :include => :details
          default_scope -> { includes(:"details_of_#{self.name.tableize}").references(:"details_of_#{self.name.tableize}") }
          
          alias :details  :"details_of_#{self.name.tableize}"
          alias :details= :"details_of_#{self.name.tableize}="
	  
	  after_initialize do
	    self.details ||= Object.const_get("#{self.class.superclass.name}#{self.class.name}Detail").new
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
    # Extend column_for support for "table.column" notation
    #
    # This gives us power to do eg.:
    #  has_many :frames, foreign_key: "project_frame_details.glass_id"    
    def column_for(table_name, column_name)
      if column_name.match /\./
        table_name, column_name = column_name.split(/\./)
      end
      
      super table_name, column_name
    end
  end
end

ActiveRecord::Associations::AssociationScope.send :include, Detailed::AssociationScope
