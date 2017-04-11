module Agent
  class NodeUnplugger
    include Logging

    attr_reader :node

    # @param [HostNode] node
    # @param [String] connected_at
    def initialize(node, connected_at)
      @node = node
      @connected_at = connected_at
    end

    def unplug!
      info "disconnect node #{node.name || node.node_id}"

      begin
        self.update_node
        self.publish_update_event
      rescue => exc
        error exc.message
      end
    end

    def update_node
      result  = HostNode.where(:id => node.id, :connected_at => @connected_at).update(:connected => false)
      if result['updatedExisting']
        info "Unplugged node #{@node.to_path} at #{@connected_at}"
        deleted_at = Time.now.utc
        node.containers.unscoped.where(:container_type.ne => 'volume').each do |c|
          c.with(safe: false).set(:deleted_at => deleted_at)
        end
      else
        warn "Not unplugging re-connected node #{@node.to_path} at #{@connected_at}"
      end
    end

    def publish_update_event
      node.publish_update_event
    end
  end
end
