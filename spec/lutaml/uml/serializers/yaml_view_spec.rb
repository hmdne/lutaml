require 'spec_helper'
require 'lutaml/uml/serializers/yaml_view'

RSpec.describe Lutaml::Uml::Serializers::YamlView do
  describe '#new' do
    subject(:serialize) { described_class.new(yaml_content) }

    let(:yaml_content) do
      YAML.load(File.read(fixtures_path('datamodel/views/TopDown.yml')))
    end

    it 'Correctly parses passed yaml file' do
      expect(serialize.name).to eq(yaml_content['name'])
      expect(serialize.title).to eq(yaml_content['title'])
      expect(serialize.caption).to eq(yaml_content['caption'])
      expect(serialize.classes.first)
        .to(be_instance_of(Lutaml::Uml::Serializers::Class))
    end
  end
end
