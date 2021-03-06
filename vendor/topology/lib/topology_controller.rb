require 'command_line'
require 'topology'

# This controller collects network topology information using LLDP.
class TopologyController < Trema::Controller
  timer_event :flood_lldp_frames, interval: 1.sec

  attr_reader :topology

  def initialize(&block)
    super
    @command_line = CommandLine.new(logger)
    @topology = Topology.new
    block.call self
  end

  def start(args = [])
    @command_line.parse(args)
    @topology.add_observer @command_line.view
    logger.info "Topology started (#{@command_line.view})."
    self
  end

  def add_observer(observer)
    @topology.add_observer observer
  end

  def switch_ready(dpid)
    send_message dpid, Features::Request.new
  end

  def features_reply(dpid, features_reply)
    @topology.add_switch dpid, features_reply.physical_ports.select(&:up?)
  end

  def switch_disconnected(dpid)
    @topology.delete_switch dpid
  end

  def port_modify(_dpid, port_status)
    updated_port = port_status.desc
    return if updated_port.local?
    if updated_port.down?
      @topology.delete_port updated_port
    elsif updated_port.up?
      @topology.add_port updated_port
    else
      fail 'Unknown port status.'
    end
  end

  def packet_in(dpid, packet_in)
    case packet_in.data
    when Arp::Request
#      p packet_in.data
      @topology.maybe_add_host(packet_in.source_mac,
                               packet_in.sender_protocol_address,
                               dpid,
                               packet_in.in_port)
    when Arp::Reply
#      p packet_in.data
      @topology.maybe_add_host(packet_in.source_mac,
                               packet_in.sender_protocol_address,
                               dpid,
                               packet_in.in_port)
    end
    if packet_in.lldp?
      @topology.maybe_add_link Link.new(dpid, packet_in)
    #elsif packet_in.data.is_a? Arp
    elsif packet_in.data.is_a? Parser::IPv4Packet
      if packet_in.source_ip_address.to_s != "0.0.0.0"
        @topology.maybe_add_host(packet_in.source_mac,
                                 packet_in.source_ip_address,
                                 dpid,
                                 packet_in.in_port)
      end
#    else
#      @topology.maybe_add_host(packet_in.source_mac,
#                               packet_in.source_ip_address,
#                               dpid,
#                               packet_in.in_port)
    end
  end

  def flood_lldp_frames
    @topology.ports.each do |dpid, ports|
      send_lldp dpid, ports
    end
  end

  def flood_packets(packet_in)
    @topology.ports.each do |dpid, ports|
      ports.each do |port|
        send_packet_out(
                                dpid,
                                raw_data: packet_in.data.to_binary,
                                actions: SendOutPort.new(port.number))
      end
    end
  end
  private

  def send_lldp(dpid, ports)
    ports.each do |each|
      port_number = each.number
      send_packet_out(
        dpid,
        actions: SendOutPort.new(port_number),
        raw_data: lldp_binary_string(dpid, port_number)
      )
    end
  end

  def lldp_binary_string(dpid, port_number)
    destination_mac = @command_line.destination_mac
    if destination_mac
      Pio::Lldp.new(dpid: dpid,
                    port_number: port_number,
                    destination_mac: destination_mac).to_binary
    else
      Pio::Lldp.new(dpid: dpid, port_number: port_number).to_binary
    end
  end
end
