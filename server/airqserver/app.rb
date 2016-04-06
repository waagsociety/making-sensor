require 'sinatra'
require 'rubygems'
require 'yaml'
require 'pg'



class AirqApp < Sinatra::Base
  dir = File.dirname(File.expand_path(__FILE__))
  ms_conf = YAML.load_file("#{dir}/../conf/makingsense.yaml")

  get '/lastsensordata' do
    puts ms_conf
    conn = PGconn.open(
      :host => ms_conf['db']['host'],
      :port => ms_conf['db']['port'],
      :options => ms_conf['db']['options'],
      :tty =>  ms_conf['db']['tty'],
      :dbname => ms_conf['db']['dbname'],
      :user => ms_conf['db']['user'],
      :password => ms_conf['db']['password']
    )
    res= conn.exec("SELECT * FROM #{ms_conf['db']['measurestable']}")
    puts res
    conn.close()
  end
end
