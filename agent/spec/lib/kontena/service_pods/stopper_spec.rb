
describe Kontena::ServicePods::Stopper do

  let(:service_id) { 'service-id' }
  let(:subject) { described_class.new(service_id, 1) }

  describe '#perform' do

    let(:container) do
      double(:container, :running? => true, :name => '/foo', :stop_grace_period => 10)
    end

    before(:each) do
      allow(subject).to receive(:get_container).and_return(container)
    end

    it 'stops container' do
      expect(container).to receive(:stop).with({'timeout' => 10})
      subject.perform
    end

    it 'stops container with a configured timeout' do
      expect(container).to receive(:stop_grace_period).and_return(20)
      expect(container).to receive(:stop).with({'timeout' => 20})
      subject.perform
    end
  end
end
