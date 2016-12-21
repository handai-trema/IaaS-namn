require 'active_support/core_ext/class/attribute_accessors'
require 'drb'
require 'json'
require 'path_manager'
require 'port'
require 'slice_exceptions'
require 'slice_extensions'
require 'view/html'

# Virtual slice.
# rubocop:disable ClassLength
class Slice
  extend DRb::DRbUndumped
  include DRb::DRbUndumped

  cattr_accessor(:all, instance_reader: false) { [] }

  def self.create(name)
    if find_by(name: name)
      fail SliceAlreadyExistsError, "Slice #{name} already exists"
    end
    new(name).tap { |slice| all << slice }
    Html.update(all)
  end

  # This method smells of :reek:NestedIterators but ignores them
  def self.find_by(queries)
    queries.inject(all) do |memo, (attr, value)|
      memo.find_all { |slice| slice.__send__(attr) == value }
    end.first
  end

  def self.find_by!(queries)
    find_by(queries) || fail(SliceNotFoundError,
                             "Slice #{queries.fetch(:name)} not found")
  end

  def self.find(&block)
    all.find(&block)
  end

  def self.destroy(name)
    puts "dest"
    find_by!(name: name)
    Path.find { |each| each.slice == name }.each(&:destroy)
    all.delete_if { |each| each.name == name }
  end

  def self.destroy_all
    all.clear
  end

  def self.split(org_slice, slice1, slice2)
#    if opt == "--slice"
      slice1, hosts1 = slice1.split(":",2)
#      puts slice1
#      puts hosts1
      slice2, hosts2 = slice2.split(":",2)
#      puts slice2
#      puts hosts2
      hosts1 = hosts1.split(",")
      hosts2 = hosts2.split(",")
      if find_by(name: slice1)
        fail SliceAlreadyExistsError, "Slice #{slice1} already exists"
      end
      if find_by(name: slice2)
        fail SliceAlreadyExistsError, "Slice #{slice2} already exists"
      end
      create(slice1)
      create(slice2)
      org_slice = find_by!(name: org_slice)
      slice1 = find_by!(name: slice1)
      slice2 = find_by!(name: slice2)
      hosts1.each do |each|
        org_slice.ports.each do |each2|
          if org_slice.find_mac_address(each2, each)
            slice1.add_mac_address(each, each2)
            org_slice.delete_mac_address(each, each2)
            org_slice.delete_port(each2)
          end
        end
      end
      hosts2.each do |each|
        org_slice.ports.each do |each2|
          if org_slice.find_mac_address(each2, each)
            slice2.add_mac_address(each, each2)
            org_slice.delete_mac_address(each, each2)
            org_slice.delete_port(each2)
          end
        end
      end
#    end    
    #new(name).tap { |slice| all << slice }
    Html.update(Slice.all)

  end


 def self.merge(slice1, slice2, merged_slice)
#    if opt == "--slice"
      if find_by(name: merged_slice)
        fail SliceAlreadyExistsError, "Slice #{merged_slice} already exists"
      end
      create(merged_slice)
      merged_slice = find_by!(name: merged_slice)
      slice1 = find_by!(name: slice1)
      slice2 = find_by!(name: slice2)
      slice1.ports.each do |each|
        slice1.mac_addresses(each).each do |each2|
          merged_slice.add_mac_address(each2, each)
          slice1.delete_port(each)
        end
      end
      slice2.ports.each do |each|
        slice2.mac_addresses(each).each do |each2|
          merged_slice.add_mac_address(each2, each)
          slice2.delete_port(each)
        end
      end
#    end
    #new(name).tap { |slice| all << slice }
    Html.update(Slice.all)
  end


  attr_reader :name

  def initialize(name)
    @name = name
    @ports = Hash.new([].freeze)
  end
  private_class_method :new

  def add_port(port_attrs)
    port = Port.new(port_attrs)
    if @ports.key?(port)
      fail PortAlreadyExistsError, "Port #{port.name} already exists"
    end
    @ports[port] = [].freeze
  end

  def delete_port(port_attrs)
    find_port port_attrs
    Path.find { |each| each.slice == @name }.select do |each|
      each.port?(Topology::Port.create(port_attrs))
    end.each(&:destroy)
    @ports.delete Port.new(port_attrs)
  end

  def find_port(port_attrs)
    mac_addresses port_attrs
    Port.new(port_attrs)
  end

  def each(&block)
    @ports.keys.each do |each|
      block.call each, @ports[each]
    end
  end

  def ports
    @ports.keys
  end

  def add_mac_address(mac_address, port_attrs)
    port = Port.new(port_attrs)
    if @ports[port].include? Pio::Mac.new(mac_address)
      fail(MacAddressAlreadyExistsError,
           "MAC address #{mac_address} already exists")
    end
    @ports[port] += [Pio::Mac.new(mac_address)]
    #new(name).tap { |slice| all << slice }
    Html.update(Slice.all)
  end

  def delete_mac_address(mac_address, port_attrs)
    find_mac_address port_attrs, mac_address
    @ports[Port.new(port_attrs)] -= [Pio::Mac.new(mac_address)]

    Path.find { |each| each.slice == @name }.select do |each|
      each.endpoints.include? [Pio::Mac.new(mac_address),
                               Topology::Port.create(port_attrs)]
    end.each(&:destroy)
  end

  def find_mac_address(port_attrs, mac_address)
    find_port port_attrs
    mac = Pio::Mac.new(mac_address)
    if @ports[Port.new(port_attrs)].include? mac
      mac
    else
#      fail MacAddressNotFoundError, "MAC address #{mac_address} not found"
    end
  end

  def mac_addresses(port_attrs)
    port = Port.new(port_attrs)
    @ports.fetch(port)
  rescue KeyError
    raise PortNotFoundError, "Port #{port.name} not found"
  end

  def member?(host_id)
    @ports[Port.new(host_id)].include? host_id[:mac]
  rescue
    false
  end

  def to_s
    @name
  end

  def to_json(*_)
    %({"name": "#{@name}"})
  end

  def method_missing(method, *args, &block)
    @ports.__send__ method, *args, &block
  end

end
# rubocop:enable ClassLength
