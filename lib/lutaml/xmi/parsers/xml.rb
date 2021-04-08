require "nokogiri"
require "lutaml/uml/has_attributes"
require "lutaml/uml/document"

module Lutaml
  module XMI
    module Parsers
      # Class for parsing .xmi schema files into ::Lutaml::Uml::Document
      class XML
        LOVER_VALUE_MAPPINGS = {
          "0" => "C",
          "1" => "M"
        }
        attr_reader :main_model, :xmi_cache

        # @param [String] io - file object with path to .xmi file
        #        [Hash] options - options for parsing
        #
        # @return [Lutaml::XMI::Model::Document]
        def self.parse(io, options = {})
          new.parse(Nokogiri::XML(io.read))
        end

        def parse(xmi_doc)
          @xmi_cache = {}
          @main_model = xmi_doc
          ::Lutaml::Uml::Document
            .new(serialize_to_hash(xmi_doc))
        end

        private

        def serialize_to_hash(xmi_doc)
          main_model = xmi_doc.xpath('//uml:Model[@xmi:type="uml:Model"]').first
          {
            name: main_model["name"],
            packages: serialize_model_packages(main_model)
          }
        end

        def serialize_model_packages(main_model)
          main_model.xpath('./packagedElement[@xmi:type="uml:Package"]').map do |package|
            {
              name: package["name"],
              packages: serialize_model_packages(package),
              classes: serialize_model_classes(package),
              enums: serialize_model_enums(package)
            }
          end
        end

        def serialize_model_classes(model)
          model.xpath('./packagedElement[@xmi:type="uml:Class"]').map do |klass|
            {
              xmi_id: klass['xmi:id'],
              xmi_uuid: klass['xmi:uuid'],
              name: klass['name'],
              attributes: serialize_class_attributes(klass),
              associations: serialize_model_associations(klass),
              is_abstract: doc_node_attribute_value(klass, 'isAbstract'),
              definition: doc_node_attribute_value(klass, 'documentation'),
              stereotype: doc_node_attribute_value(klass, 'stereotype')
            }
          end
        end

        def serialize_model_enums(model)
          model.xpath('./packagedElement[@xmi:type="uml:Enumeration"]').map do |enum|
            attributes = enum
                          .xpath('.//ownedLiteral[@xmi:type="uml:EnumerationLiteral"]')
                          .map do |attribute|
                            {
                              # TODO: xmi_id
                              # xmi_id: enum['xmi:id'],
                              type: attribute['name'],
                            }
                          end
            {
              xmi_id: enum['xmi:id'],
              xmi_uuid: enum['xmi:uuid'],
              name: enum['name'],
              attributes: attributes,
              definition: doc_node_attribute_value(enum, 'documentation'),
              stereotype: doc_node_attribute_value(enum, 'stereotype')
            }
          end
        end

        def serialize_model_associations(klass)
          return unless klass.attributes['name']

          klass.xpath('.//ownedAttribute[@association]').map do |assoc|
            type = assoc.xpath('.//type').first
            if type && type.attributes && type.attributes['idref']
              id_ref = type.attributes['idref'].value
              member_end = lookup_entity_name(id_ref)
            end
            if member_end
              {
                xmi_id: assoc['xmi:id'],
                xmi_uuid: assoc['xmi:uuid'],
                name: assoc['name'],
                member_end: member_end,
                member_end_cardinality: { 'min' => cardinality_min_value(assoc), 'max' => cardinality_max_value(assoc) },
              }
            end
          end.compact
        end

        def serialize_class_attributes(klass)
          klass.xpath('.//ownedAttribute[@xmi:type="uml:Property"]').map do |attribute|
            type = attribute.xpath('.//type').first || {}
            if attribute.attributes['association'].nil?
              {
                # TODO: xmi_id
                # xmi_id: klass['xmi:id'],
                name: attribute['name'],
                type: lookup_entity_name(type['xmi:idref']) || type['xmi:idref'],
                is_derived: attribute['isDerived'],
                cardinality: { 'min' => cardinality_min_value(attribute), 'max' => cardinality_max_value(attribute) },
                definition: lookup_attribute_definition(attribute)
              }
            end
          end.compact
        end

        def cardinality_min_value(node)
          lower_value_node = node.xpath('.//lowerValue').first
          return unless lower_value_node

          lower_value = lower_value_node.attributes['value']&.value
          LOVER_VALUE_MAPPINGS[lower_value]
        end

        def cardinality_max_value(node)
          upper_value_node = node.xpath('.//upperValue').first
          return unless upper_value_node

          upper_value_node.attributes['value']&.value
        end

        def doc_node_attribute_value(node, attr_name)
          xmi_id = node['xmi:id']
          doc_node = main_model.xpath(%Q(//element[@xmi:idref="#{xmi_id}"]/properties)).first
          return unless doc_node

          doc_node.attributes[attr_name]&.value
        end

        def lookup_attribute_definition(node)
          xmi_id = node['xmi:id']
          doc_node = main_model.xpath(%Q(//attribute[@xmi:idref="#{xmi_id}"]/documentation)).first
          return unless doc_node

          doc_node.attributes['value']&.value
        end

        def lookup_entity_name(xmi_id)
          xmi_cache[xmi_id] ||= model_node_name_by_xmi_id(xmi_id)
          xmi_cache[xmi_id]
        end

        def model_node_name_by_xmi_id(xmi_id)
          node = main_model.xpath(%Q(//*[@xmi:id="#{xmi_id}"])).first
          return unless node

          node.attributes['name']&.value
        end
      end
    end
  end
end