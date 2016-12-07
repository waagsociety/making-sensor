load './lora-agent.rb'


# here the main part starts
dir = File.dirname(File.expand_path(__FILE__))
ms_conf = YAML.load_file("#{dir}/../conf/makingsense.yaml")
puts ms_conf

myagent = LoraAgent.new(ms_conf['ttnmqtt'],ms_conf['lorasensordb'],ms_conf['smartcitizenme'])

myagent.read_and_upload()



at_exit do
  myagent.clean_up()
  puts "Program exited"
end
