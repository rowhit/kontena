require_relative '../../app/middlewares/websocket_backend'

describe WebsocketBackend, celluloid: true, eventmachine: true do
  let(:app) { spy(:app) }
  let(:subject) { described_class.new(app) }

  before(:each) do
    stub_const('Server::VERSION', '0.9.1')
  end

  after(:each) do
    subject.stop_rpc_server
  end

  describe '#our_version' do
    it 'retuns baseline version with patch level 0' do
      expect(subject.our_version).to eq('0.9.0')
    end
  end

  describe '#valid_agent_version?' do
    it 'returns true when exact match' do
      expect(subject.valid_agent_version?('0.9.1')).to eq(true)
    end

    it 'returns true when exact match with beta' do
      stub_const('Server::VERSION', '0.9.0.beta')
      expect(subject.valid_agent_version?('0.9.0.beta')).to eq(true)
    end

    it 'returns true when patch level is greater' do
      expect(subject.valid_agent_version?('0.9.2')).to eq(true)
    end

    it 'returns true when patch level is less than' do
      expect(subject.valid_agent_version?('0.9.0')).to eq(true)
    end

    it 'returns false when minor version is different' do
      expect(subject.valid_agent_version?('0.8.4')).to eq(false)
    end

    it 'returns false when major version is different' do
      expect(subject.valid_agent_version?('1.0.1')).to eq(false)
    end
  end

  describe '#subscribe_to_rpc_channel' do
    let(:client) do
      {
          ws: spy(:ws)
      }
    end

    it 'sends message if client is found' do
      allow(subject).to receive(:client_for_id).and_return(client)
      expect(subject).to receive(:send_message).with(client[:ws], 'hello')
      MongoPubsub.publish('rpc_client', {type: 'request', message: 'hello'})
      sleep 0.05
      EM.run_deferred_callbacks
    end

    it 'does not send message if client is not found' do
      expect(subject).not_to receive(:send_message).with(client[:ws], 'hello')
      MongoPubsub.publish('rpc_client', {type: 'request', message: 'hello'})
      sleep 0.05
    end
  end

  describe '#on_pong' do
    let(:logger) { instance_double(Logger) }
    before do
      allow(subject).to receive(:logger).and_return(logger)
      allow(logger).to receive(:debug)
    end

    let(:client_ws) { instance_double(Faye::WebSocket) }
    let(:client) do
      { id: 'aa', ws: client_ws }
    end

    let(:grid) do
      Grid.create!(name: 'test')
    end

    let(:node) do
      HostNode.create!(name: 'test-node', node_id: 'aa', grid: grid)
    end

    it 'closes the websocket if client is not found' do
      client[:id] = 'bb'
      expect(subject.logger).to receive(:warn).with('Close connection of missing node bb')
      expect(client_ws).to receive(:close)
      expect(subject).to receive(:unplug_client).with(client)

      subject.on_pong(client, 0.1)
    end

    it 'closes connection if node is not marked as connected' do
      node.set(connected: false)
      expect(subject.logger).to receive(:warn).with('Close connection of disconnected node test-node')
      expect(client_ws).to receive(:close)
      expect(subject).to receive(:unplug_client).with(client)

      subject.on_pong(client, 0.1)
    end

    it 'updates node last_seen_at if node is marked as connected' do
      expect(subject.logger).to_not receive(:warn)

      node.set(connected: true)
      expect(client_ws).not_to receive(:close)

      expect {
        subject.on_pong(client, 0.1)
      }.to change { node.reload.last_seen_at }
    end

    it 'logs a warning if ping delay is over threshold' do
      node.set(connected: true)

      expect(subject.logger).to receive(:warn).with('keepalive ping 3.00s of 5.00s timeout from client aa')
      expect(client_ws).not_to receive(:close)

      subject.on_pong(client, 3.0)
    end
  end
end
