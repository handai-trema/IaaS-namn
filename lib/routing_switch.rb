$LOAD_PATH.unshift File.join(__dir__, '../vendor/topology/lib')

require 'active_support/core_ext/module/delegation'
require 'optparse'
require 'path_in_slice_manager'
require 'path_manager'
require 'topology_controller'
require 'arp_table'

# L2 routing switch
class RoutingSwitch < Trema::Controller
  # Command-line options of RoutingSwitch
  class Options
    attr_reader :slicing

    def initialize(args)
      @opts = OptionParser.new
      @opts.on('-s', '--slicing') { @slicing = true }
      @opts.parse [__FILE__] + args
    end
  end

  timer_event :flood_lldp_frames, interval: 1.sec

  delegate :flood_lldp_frames, to: :@topology

  def slice
    fail 'Slicing is disabled.' unless @options.slicing
    Slice
  end

  def start(args)
    @options = Options.new(args)
    @path_manager = start_path_manager
    @topology = start_topology
    @arp_table = ArpTable.new
    logger.info 'Routing Switch started.'
  end

  delegate :switch_ready, to: :@topology
  delegate :features_reply, to: :@topology
  delegate :switch_disconnected, to: :@topology
  delegate :port_modify, to: :@topology

  def packet_in(dpid, packet_in)
    #puts packet_in.in_port
    #puts packet_in.data
    @topology.packet_in(dpid, packet_in)
    @path_manager.packet_in(dpid, packet_in) unless packet_in.lldp?
    case packet_in.data
    when Arp::Request
      packet_in_arp_request dpid, packet_in
    when Arp::Reply
      packet_in_arp_reply dpid, packet_in
    end
  end

  private

  def start_path_manager
    fail unless @options
    (@options.slicing ? PathInSliceManager : PathManager).new.tap(&:start)
  end

  def start_topology
    fail unless @path_manager
    TopologyController.new { |topo| topo.add_observer @path_manager }.start
  end

  def packet_in_arp_request(dpid, packet_in)
    @topology.flood_packets(packet_in)
  end

  def packet_in_arp_reply(dpid, packet_in)
    @topology.flood_packets(packet_in)
  end
end
