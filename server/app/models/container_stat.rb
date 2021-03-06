class ContainerStat
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :spec, type: Hash
  field :cpu, type: Hash
  field :memory, type: Hash
  field :filesystem, type: Array
  field :diskio, type: Hash
  field :network, type: Hash

  belongs_to :grid
  belongs_to :host_node
  belongs_to :grid_service
  belongs_to :container

  index({ grid_id: 1 }, { background: true })
  index({ grid_service_id: 1 }, { background: true })
  index({ container_id: 1 }, { background: true })
  index({ created_at: 1 }, { background: true })
  index({ grid_service_id: 1, created_at: 1 }, { background: true })

  def self.calculate_num_cores(cpu_mask)
    if cpu_mask
      cpu_mask.split('-').last.to_i + 1
    else
      1
    end
  end

  def self.get_aggregate_stats_for_service(service_id, from_time, to_time)
    self.collection.aggregate([
    {
      '$match': {
        grid_service_id: service_id,
        created_at: {
          '$gte': from_time,
          '$lte': to_time
        }
      }
    },
    {
      '$group': {
        _id: {
          year: { '$year': '$created_at' },
          month: { '$month': '$created_at' },
          day: { '$dayOfMonth': '$created_at' },
          hour: { '$hour': '$created_at' },
          minute: { '$minute': '$created_at' },
          container_id: '$container_id'
        },
        created_at: { '$first': '$created_at' },

        cpu_mask: { '$first': '$spec.cpu.mask' },
        cpu_percent_used: { '$avg': '$cpu.usage_pct' },

        memory_used: { '$avg': '$memory.usage' },
        memory_total: { '$first': '$spec.memory.limit' },

        network_internal_interfaces: { '$first': '$network.internal.interfaces' },
        network_internal_rx_bytes: { '$avg': '$network.internal.rx_bytes' },
        network_internal_rx_bytes_per_second: { '$avg': '$network.internal.rx_bytes_per_second' },
        network_internal_tx_bytes: { '$avg': '$network.internal.tx_bytes' },
        network_internal_tx_bytes_per_second: { '$avg': '$network.internal.tx_bytes_per_second' },
        network_external_interfaces: { '$first': '$network.external.interfaces' },
        network_external_rx_bytes: { '$avg': '$network.external.rx_bytes' },
        network_external_rx_bytes_per_second: { '$avg': '$network.external.rx_bytes_per_second' },
        network_external_tx_bytes: { '$avg': '$network.external.tx_bytes' },
        network_external_tx_bytes_per_second: { '$avg': '$network.external.tx_bytes_per_second' }
      }
    },
    {
      '$group': {
        _id: {
          year: '$_id.year',
          month: '$_id.month',
          day: '$_id.day',
          hour: '$_id.hour',
          minute: '$_id.minute'
        },
        created_at: { '$first': '$created_at' },

        cpu_mask: { '$first': '$cpu_mask' },
        cpu_percent_used: { '$avg': '$cpu_percent_used' },

        memory_used: { '$sum': '$memory_used' },
        memory_total: { '$sum': '$memory_total' },

        network_internal_interfaces: { '$first': '$network_internal_interfaces' },
        network_internal_rx_bytes: { '$sum': '$network_internal_rx_bytes' },
        network_internal_rx_bytes_per_second: { '$sum': '$network_internal_rx_bytes_per_second' },
        network_internal_tx_bytes: { '$sum': '$network_internal_tx_bytes' },
        network_internal_tx_bytes_per_second: { '$sum': '$network_internal_tx_bytes_per_second' },
        network_external_interfaces: { '$first': '$network_external_interfaces' },
        network_external_rx_bytes: { '$sum': '$network_external_rx_bytes' },
        network_external_rx_bytes_per_second: { '$sum': '$network_external_rx_bytes_per_second' },
        network_external_tx_bytes: { '$sum': '$network_external_tx_bytes' },
        network_external_tx_bytes_per_second: { '$sum': '$network_external_tx_bytes_per_second' }
      }
    },
    {
      '$sort': { 'created_at': 1 }
    },
    {
      '$project': {
        _id: 0,
        timestamp: '$_id',
        cpu: {
          mask: '$cpu_mask',
          percent_used: '$cpu_percent_used'
        },
        memory: {
          used: '$memory_used',
          total: '$memory_total'
        },
        network: {
          internal: {
            interfaces: '$network_internal_interfaces',
            rx_bytes: '$network_internal_rx_bytes',
            rx_bytes_per_second: '$network_internal_rx_bytes_per_second',
            tx_bytes: '$network_internal_tx_bytes',
            tx_bytes_per_second: '$network_internal_tx_bytes_per_second'
          },
          external: {
            interfaces: '$network_external_interfaces',
            rx_bytes: '$network_external_rx_bytes',
            rx_bytes_per_second: '$network_external_rx_bytes_per_second',
            tx_bytes: '$network_external_tx_bytes',
            tx_bytes_per_second: '$network_external_tx_bytes_per_second'
          }
        }
      }
    }
    ]).map do |stat|
      # convert CPU mask to num_cores
      stat["cpu"]["num_cores"] = calculate_num_cores(stat["cpu"]["mask"])
      stat["cpu"].delete("mask")
      stat
    end
  end
end
