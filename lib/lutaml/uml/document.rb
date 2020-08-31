# frozen_string_literal: true

require "lutaml/uml/class"
require "lutaml/uml/enum"

module Lutaml
  module Uml
    class Document
      include HasAttributes
      include HasMembers

      attr_accessor :name,
                    :title,
                    :caption,
                    :groups,
                    :fidelity,
                    :fontname

      # rubocop:disable Rails/ActiveRecordAliases
      def initialize(attributes = {})
        update_attributes(attributes)
      end
      # rubocop:enable Rails/ActiveRecordAliases

      def classes=(value)
        @classes = value.to_a.map { |attributes| Class.new(attributes) }
      end

      def enums=(value)
        @enums = value.to_a.map { |attributes| Enum.new(attributes) }
      end

      def associations=(value)
        @associations = value.to_a.map do |attributes|
          Association.new(attributes)
        end
      end

      def classes
        @classes || []
      end

      def enums
        @enums || []
      end

      def associations
        @associations || []
      end
    end
  end
end
