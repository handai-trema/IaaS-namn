require 'json'
require 'slice'
  class Html
    def initialize()#(output = 'topology.html')
    end
    def self.update(slices)
      @slicearray=[]
      @slicetocount={}
      @slicetohost={}
      @outputname = "./lib/view/sliceoutput.html"
      count=0
     # puts slices
      slices.each do |each|
        @slicearray.push(each.name)
	@slicetohost[each.name]=[]
        each.ports.each do |each2|
          each.mac_addresses(each2).each do |each3|
	    if !each3.nil? then
              @slicetohost[each.name].push(each3.to_s)
 	    end
          end
        end
      end
      print @slicetohost
      print "\n"
      base =File.read("./lib/view/create_vis_base.txt")
      base2 =File.read("./lib/view/create_vis_base2.txt")
      main=""
      @slicearray.each do |each|
	@slicetocount[each]=count
	main+="addSliceExample(\""+count.to_s+"\",\""+each+"\")\n"
        count+=1
      end
      @slicetohost.each do|key,value|
	if !value.nil? then
	value.each do |key2,value2|
 	  main+="addHost(\""+key2+"\",\""+@slicetocount[key].to_s+"\")\n"
	end
        end
      end
      result=base+main+base2
      File.write(@outputname, result)
    end
  end

