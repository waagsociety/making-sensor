require 'rubygems'
#require 'bundler/setup'

require 'faraday'
require 'faraday_middleware'
require 'json'
require 'pg'
require 'yaml'


# http://tools.amsterdamopendata.nl/ndw/data/reistijdenAmsterdam.geojson
# http://data.amsterdam.nl/dataset/realtime-verkeersdata/resource/217a9825-2338-49e6-a5f9-38399575f836#
# http://data.amsterdam.nl/dataset/actuele_verkeersgegevens_nationaal

def httpget(host, path, user_agent='Waag agent', timeout=5, open_timeout=2)

  connection = Faraday.new(host) do |c|
    c.use FaradayMiddleware::FollowRedirects, limit: 3
    c.use Faraday::Response::RaiseError       # raise exceptions on 40x, 50x responses
    c.use Faraday::Adapter::NetHttp
  end

  connection.headers[:user_agent] = user_agent

  response = nil

  begin
    response = connection.get do |req|
      req.url(path)
      req.options[:timeout] = timeout
      req.options[:open_timeout] = open_timeout
    end
  rescue Faraday::Error::ClientError => e
    $stderr.puts "Error: #{e.class.name}, #{e.message} in getting json, response: #{response.to_s}, skipping time slot"
  end

  return response
end


def conn_on(tt_conf)
  conn = PGconn.open(
    :host => tt_conf['trafficdb']['host'],
    :port => tt_conf['trafficdb']['port'],
    :options => tt_conf['trafficdb']['options'],
    :tty =>  tt_conf['trafficdb']['tty'],
    :dbname => tt_conf['trafficdb']['dbname'],
    :user => tt_conf['trafficdb']['user'],
    :password => tt_conf['trafficdb']['password']
  )

  conn.prepare("trafficdata", "INSERT INTO #{tt_conf['trafficdb']['traffictable']} (id,name,type,timestmp,length,traveltime,velocity, coordinates)" +
      " SELECT $1::character varying(100), $2::character varying(100), $3::character varying(10),$4::timestamp with time zone, $5::integer, $6::integer, $7::integer, ST_GeomFromText($8::text)" +
      " WHERE NOT EXISTS (SELECT 1 FROM #{tt_conf['trafficdb']['traffictable']} WHERE id=$1::character varying(100) AND timestmp = $4::timestamp with time zone);" )

  return conn
end

def conn_off(conn)
  unless conn.nil?
    conn.close()
  end
end

def parse_traject(properties, geometry)
  tuples = geometry['coordinates'].map { |coordinate|
     coordinate.join(' ')
   }.join(',')

  #puts tuples

  properties['coordinates'] = geometry['type'] + '(' + tuples + ')'
  #puts properties.to_s

  return properties
end

def insert_data(conn,data)
  res = conn.exec_prepared("trafficdata",[data['Id'], data['Name'], data['Type'], data['Timestamp'], data['Length'], data['Traveltime'], data['Velocity'],data['coordinates']])
end

$stdout.sync = true

conn = nil
dir = File.dirname(File.expand_path(__FILE__))
tt_conf = YAML.load_file("#{dir}/../conf/makingsense.yaml")

  response = httpget(tt_conf['trafficdata']['host'], tt_conf['trafficdata']['path'], tt_conf['trafficdata']['user_agent'])


if (response.is_a?(Faraday::Response) && response.status == 200)
  begin
    trajecten = JSON.parse(response.body)
    conn = conn_on(tt_conf)
    trajecten['features'].each do |traject|
      begin
      data = parse_traject(traject['properties'], traject['geometry'])
      insert_data(conn,data)
      rescue Exception => e
        $stderr.puts "Error: " + e.message + " in processing line: " + traject.to_s + ", continuing"
      end
    end
  rescue Exception => e
    $stderr.puts "Error: " + e.message + " in processing response: " + response.body + ", skipping"
  end
end

at_exit do
  #puts "Closing DB connections #{conn.to_s}"
  conn_off(conn)
end
