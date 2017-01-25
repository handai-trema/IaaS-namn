$LOAD_PATH.unshift File.join(__dir__, '../vendor/topology/lib')

require 'active_support/core_ext/module/delegation'
require 'optparse'
require 'path_in_slice_manager'
require 'path_manager'
require 'topology_controller'
require 'arp_table'
require 'interface'

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
    @interfaces = Interface.load_configuration Configuration::INTERFACES
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
    case packet_in.data
    when Arp::Request
      packet_in_arp_request dpid, packet_in.in_port, packet_in.data
    when Arp::Reply
      packet_in_arp_reply dpid, packet_in
    when Parser::IPv4Packet
      packet_in_ipv4 dpid, packet_in
    end
    @topology.packet_in(dpid, packet_in)
    @path_manager.packet_in(dpid, packet_in) unless packet_in.lldp?
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

  # rubocop:disable MethodLength
  def packet_in_arp_request(dpid, in_port, arp_request)
    interface =
      Interface.find_by(port_number: in_port,
                        ip_address: arp_request.target_protocol_address)
    return unless interface
    send_packet_out(
      dpid,
      raw_data: Arp::Reply.new(
        destination_mac: arp_request.source_mac,
        source_mac: interface.mac_address,
        sender_protocol_address: arp_request.target_protocol_address,
        target_protocol_address: arp_request.sender_protocol_address
      ).to_binary,
      actions: SendOutPort.new(in_port))
  end
  # rubocop:enable MethodLength

  def packet_in_arp_reply(dpid, packet_in)
    @arp_table.update(packet_in.in_port,
                      packet_in.sender_protocol_address,
                      packet_in.source_mac)
    flush_unsent_packets(dpid,
                         packet_in.data,
                         Interface.find_by(port_number: packet_in.in_port))
  end

  def packet_in_ipv4(dpid, packet_in)
    if forward?(packet_in)
      forward(dpid, packet_in)
    elsif packet_in.ip_protocol == 1
      icmp = Icmp.read(packet_in.raw_data)
      packet_in_icmpv4_echo_request(dpid, packet_in) if icmp.icmp_type == 8
    else
      logger.debug "Dropping unsupported IPv4 packet: #{packet_in.data}"
    end
  end

  # rubocop:disable MethodLength
  def packet_in_icmpv4_echo_request(dpid, packet_in)
    icmp_request = Icmp.read(packet_in.raw_data)
    if @arp_table.lookup(packet_in.source_ip_address)
      send_packet_out(dpid,
                      raw_data: create_icmp_reply(icmp_request).to_binary,
                      actions: SendOutPort.new(packet_in.in_port))
    else
      send_later(dpid,
                 interface: Interface.find_by(port_number: packet_in.in_port),
                 destination_ip: packet_in.source_ip_address,
                 data: create_icmp_reply(icmp_request))
    end
  end
  # rubocop:enable MethodLength

  def print_routing_table()
      return @routing_table.getDB()
  end

  def add_routing_table_entry(destination_ip, netmask_length, next_hop)
      options = {:destination => destination_ip, :netmask_length => netmask_length, :next_hop => next_hop}
      @routing_table.add(options)
  end

  def delete_routing_table_entry(destination_ip, netmask_length)
    options = {:destination => destination_ip, :netmask_length => netmask_length}
    @routing_table.delete(options)
  end

  def print_interface()
    ret = Array.new()
    Interface.all.each do |each|
      ret << {:port_number => each.port_number, :mac_address => each.mac_address.to_s, :ip_address => each.ip_address.value.to_s, :netmask_length => each.netmask_length}
    end
    return ret
  end

  private

  def sent_to_router?(packet_in)
    return true if packet_in.destination_mac.broadcast?
    interface = Interface.find_by(port_number: packet_in.in_port)
    interface && interface.mac_address == packet_in.destination_mac
  end

  def forward?(packet_in)
    !Interface.find_by(ip_address: packet_in.destination_ip_address)
  end

  # rubocop:disable MethodLength
  # rubocop:disable AbcSize
  def forward(dpid, packet_in)
    next_hop = resolve_next_hop(packet_in.destination_ip_address)

    interface = Interface.find_by_prefix(next_hop)
    return if !interface || (interface.port_number == packet_in.in_port)

    arp_entry = @arp_table.lookup(next_hop)
    if arp_entry
      actions = [SetSourceMacAddress.new(interface.mac_address),
                 SetDestinationMacAddress.new(arp_entry.mac_address),
                 SendOutPort.new(interface.port_number)]
      send_flow_mod_add(dpid,
                        match: ExactMatch.new(packet_in), actions: actions)
      send_packet_out(dpid, raw_data: packet_in.raw_data, actions: actions)
    else
      send_later(dpid,
                 interface: interface,
                 destination_ip: next_hop,
                 data: packet_in.data)
    end
  end
  # rubocop:enable AbcSize
  # rubocop:enable MethodLength

  def resolve_next_hop(destination_ip_address)
    interface = Interface.find_by_prefix(destination_ip_address)
    if interface
      destination_ip_address
    else
      @routing_table.lookup(destination_ip_address)
    end
  end

  def create_icmp_reply(icmp_request)
    Icmp::Reply.new(identifier: icmp_request.icmp_identifier,
                    source_mac: icmp_request.destination_mac,
                    destination_mac: icmp_request.source_mac,
                    destination_ip_address: icmp_request.source_ip_address,
                    source_ip_address: icmp_request.destination_ip_address,
                    sequence_number: icmp_request.icmp_sequence_number,
                    echo_data: icmp_request.echo_data)
  end

  def send_later(dpid, options)
    destination_ip = options.fetch(:destination_ip)
    @unresolved_packet_queue[destination_ip] += [options.fetch(:data)]
    send_arp_request(dpid, destination_ip, options.fetch(:interface))
  end

  def flush_unsent_packets(dpid, arp_reply, interface)
    destination_ip = arp_reply.sender_protocol_address
    @unresolved_packet_queue[destination_ip].each do |each|
      rewrite_mac =
        [SetDestinationMacAddress.new(arp_reply.sender_hardware_address),
         SetSourceMacAddress.new(interface.mac_address),
         SendOutPort.new(interface.port_number)]
      send_packet_out(dpid, raw_data: each.to_binary_s, actions: rewrite_mac)
    end
    @unresolved_packet_queue[destination_ip] = []
  end

  def send_arp_request(dpid, destination_ip, interface)
    arp_request =
      Arp::Request.new(source_mac: interface.mac_address,
                       sender_protocol_address: interface.ip_address,
                       target_protocol_address: destination_ip)
    send_packet_out(dpid,
                    raw_data: arp_request.to_binary,
                    actions: SendOutPort.new(interface.port_number))
  end
end
# rubocop:enable ClassLength
