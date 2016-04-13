require 'faraday'
require 'json'
require 'pg'
require 'yaml'


def httpget(host, path, timeout=5, open_timeout=2)

  connection = Faraday.new(host)
  response = ''

  begin
    response = connection.get do |req|
      req.url(path)
      req.options[:timeout] = timeout
      req.options[:open_timeout] = open_timeout
    end
  rescue Exception => e
    $stderr.puts "Error: " + e.message + " in getting json, response: " + response.to_s + ", skipping time slot"
    # avoid parsing the response further in the code
    response.status = 500
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

  conn.prepare("trafficdata", "INSERT INTO #{tt_conf['trafficdb']['traffictable']} (id,name,type,timestmp,length,traveltime,velocity)" +
      " SELECT $1::character varying(100), $2::character varying(100), $3::character varying(10),$4::timestamp with time zone, $5::integer, $6::integer, $7::integer" +
      " WHERE NOT EXISTS (SELECT 1 FROM #{tt_conf['trafficdb']['traffictable']} WHERE id=$1::character varying(100) AND timestmp = $4::timestamp with time zone);" )

  return conn
end

def conn_off(conn)
  conn.close()
end

def parse_traject(traject)
  #puts traject.to_s
  return traject
end

def insert_data(conn,data)
  res = conn.exec_prepared("trafficdata",[data["Id"], data["Name"], data["Type"], data["Timestamp"], data["Length"], data["Traveltime"], data["Velocity"]])
end


dir = File.dirname(File.expand_path(__FILE__))
tt_conf = YAML.load_file("#{dir}/../conf/makingsense.yaml")

response = httpget(tt_conf['trafficdata']['host'], tt_conf['trafficdata']['path'])

if response.status == 200

  begin
    trajecten = JSON.parse(response.body)
    conn = conn_on(tt_conf)
    trajecten["features"].each do |traject|
      begin
      data = parse_traject(traject['properties'])
      insert_data(conn,data)
      rescue Exception => e
        $stderr.puts "Error: " + e.message + " in processing line: " + traject.to_s + ", continuing"
      end
    end
    conn_off(conn)
  rescue Exception => e
    $stderr.puts "Error: " + e.message + " in processing response: " + response.body + ", skipping"
  end
end
