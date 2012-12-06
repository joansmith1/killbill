#
#
#                       LOAD TESTS FOR METER MODULE
#
#
#
#
#
# 1. start a killbill server (with meter module); e.g on 127.0.0.1:8080
# 2.Run script
#   > ruby load.rb --nb-childreen <nb_children> --nb-iterations <nb-iterations> --output-directory <output-directory> --log-level DEBUG|INFO|WARN|ERR --server-ip <server-ip> --server-port <server-port>
# 3. Two files will be created:
#    - one *.csv, for all the points created for each seconds
#    - a second one *.stat to reflect min/max/avg/std for the usage post call
#
# 4. One can check using a GET that server recorded all the usage points 
#   > curl -ubob:lazar -v 'http://127.0.0.1:8080/1.0/kb/meter/f36d5557-e1d9-427a-8133-9ea49aa7e0f8?category=visit&from=2012-07-26T18:12:41&to=2013-07-26T18:12:41'
#
#
#

require 'rubygems'
require 'logger'
require 'json'
require 'optparse'
require 'net/http'


#
# Minimum stats missing methods (used as a mixin)
#
module SimpleStats

  def sum
    return self.inject(0){|acc,i|acc +i}
  end

  def average
    return self.sum/self.length.to_f
  end

  def sample_variance
    avg=self.average
    sum=self.inject(0){|acc,i|acc +(i-avg)**2}
    return(1/self.length.to_f*sum)
  end

  def standard_deviation
    return Math.sqrt(self.sample_variance)
  end
end


#
# Aggregation, CSV, Stats for counters returned by the children
#
class CounterResults

  SEP = ","

  attr_reader :children, :points, :durations
  
  def initialize(children)
    
    @children = children.flatten!
    @points = Hash.new
    @durations = []
    @durations.extend(SimpleStats)

    @children.each_with_index do |c, i|  
      
      time_sec = c.time.to_i
      current_count_for_time = 0
      if @points.has_key?(time_sec)
        current_count_for_time = @points[time_sec]
      end
      
      @points[time_sec] = current_count_for_time + 1
      @durations << c.duration
    end
    
    
    # Now sort the results
    @durations.sort
  end
  
  def min_duration
    @durations.min
  end
  
  def max_duration
    @durations.max
  end

  def avg_duration
    @durations.average
  end

  def std_duration
    @durations.standard_deviation
  end

  def points_to_csv(out)
    ordered_keys = @points.keys.sort
    ordered_values = ordered_keys.map do |k|
      @points[k]
    end 
    to_csv(out, ordered_keys, ordered_values)
  end

  private
  
  def to_csv(out, ordered_keys, ordered_values)
    result = nil
    ordered_keys.each_with_index do |k, i|
      result = k.to_s + SEP + ordered_values[i].to_s
      out.write(result)
      out.write("\n")
      out.flush
    end
  end
end


#
# Simple HTTP client class that allows to do post and get
#
class HttpClient
  
  attr_reader :host, :port
  
  def initialize(host, port)
    @host = host
    @port = port
  end
  
  
  def request(req)
     res = Net::HTTP.start(@host, @port) { |http| http.read_timeout = @default_timeout; http.request(req) }
     unless res.kind_of?(Net::HTTPSuccess) || res.kind_of?(Net::HTTPRedirection)
       handle_error(req, res)
     end
     res
  end

  def request_with_headers(req, body, headers)
     req.body = body unless body.nil?
     headers.each { |k, v| req[k.downcase] = [v] }
     request(req)
   end

  def post(uri, body=nil, headers = {})
      req = Net::HTTP::Post.new(uri)
      request_with_headers(req, body, headers)
  end
  
  def handle_error(req, res)
     raise "#{res.code}:#{res.message}\nMETHOD:#{req.method}\nURI:#{req.path}\n#{res.body}"
   end
end

#
# Parent process that forks children and wait for results to aggregate them and create outputs
#
class Parent 

  attr_reader :logger, :server_ip, :server_port, :nb_children, :output_directory, :nb_iterations, :pids, :pipes, :results, :counters
  
  def initialize(logger, server_ip, server_port, nb_children, output_directory, nb_iterations)
    @logger = logger
    @server_ip = server_ip
    @server_port = server_port
    @nb_children = nb_children.to_i 
    @output_directory = output_directory
    @nb_iterations = nb_iterations
    @pids = []
    @pipes = []
    @results= []
  end

  def run()
    begin      
      run_in_exception_blobk()
    rescue SystemExit => e
      @logger.error "Got SystemExit #{e}"
    rescue Interrupt => e
      @logger.error "Got Interrupt #{e}"
    rescue Exception => e
      @logger.error "Got Exception #{e}"
    end
    
    
    @counters = CounterResults.new(@results)
    output_results

    @logger.debug("durations min= #{@counters.min_duration} max = #{@counters.max_duration} avg = #{@counters.avg_duration} std = #{@counters.std_duration}")
  end

  private

  def output_results

    File.open(@output_directory +  output_file_prefix + ".csv", 'w') do |out|
      @counters.points_to_csv(out)
      out.flush
    end

    File.open(@output_directory +  output_file_prefix + ".stat", 'w') do |out|
      out.write("min = #{@counters.min_duration}")
      out.write("\n")
      out.write("max = #{@counters.max_duration}")
      out.write("\n")
      out.write("avg = #{@counters.avg_duration}")
      out.write("\n")
      out.write("std = #{@counters.std_duration}")
      out.write("\n")
      out.flush
    end
  end
  
  def output_file_prefix
    "/test_" + @nb_children.to_s + "_" + @nb_iterations.to_s
  end
  
  def run_in_exception_blobk()

    @nb_children.times() do |c|
      @logger.debug("Starting child #{c}")
      fork_one_child(c+1)
    end

    @nb_children.times() do |c|

      pipe_read = @pipes[c]
      res = pipe_read.read
      pipe_read.close

      child_results = Marshal.load(res)
      @results << child_results
      pid = @pids[c]

      @logger.debug("Waiting for child #{pid} c = #{c}")
      Process.wait(pid)
      @logger.debug("Child #{pid} returned with #{child_results.size}")

    end
  end
  
  
  def fork_one_child(child_id)
    
    pipe_read, pipe_write = IO.pipe

    pid = fork do
      pipe_read.close
      
      @logger.debug("Child started...")
      
      child = Child.new(@logger, @server_ip, @server_port, child_id, @nb_iterations)
      results = child.do_work
      
      Marshal.dump(results, pipe_write)
      exit!(0)
    end
    
    @pids << pid
    @pipes << pipe_read
    
    pipe_write.close
  end
end

#
# Child class that does the usage call
#  
class Child
  
  URI_BASE = "/1.0/kb/meter/f36d5557-e1d9-427a-8133-9ea49aa7e0f8/visit/"
  
  attr_reader :logger, :child_id, :nb_iterations, :server, :uri
  
  def initialize(logger, server_ip, server_port, child_id, nb_iterations)
    @logger = logger
    @logger.debug("Starting child #{child_id} with nb_iterations = #{nb_iterations}")
    @server = HttpClient.new(server_ip, server_port)
    @nb_iterations = nb_iterations.to_i
    @child_id = child_id
    @uri = URI_BASE + "load_" + child_id.to_s
  end
  
  def do_work
    results = []
    @nb_iterations.times do |i|
        child_dot = do_one_iteration
        results << child_dot
    end
    results
  end

  private

  def post_usage
    @server.post(@uri, nil, {'content-type' => 'application/json', 'Authorization' => 'Basic Ym9iOmxhemFy', 'X-Killbill-CreatedBy' => 'meter_load_test' }) 
  end

  def do_one_iteration
    before = Time.now.to_f
    post_usage
    after = Time.now.to_f
    call_time = after - before
    @logger.debug("child #{child_id} : do_one_iteration now = #{before} , sleep_time = #{call_time}")

    child_dot = ChildResultDot.new(before, call_time)
  end

  
  def do_one_iteration_test
    now = Time.now.to_f
    sleep_time = rand() + rand(0..2)
    sleep(sleep_time)
    @logger.debug("child #{child_id} : do_one_iteration now = #{now} , sleep_time = #{sleep_time}")

    child_dot = ChildResultDot.new(now, sleep_time)
  end

  class ChildResultDot
    
    attr_reader :time, :duration
    
    def initialize(time, duration)
      @time = time
      @duration = duration
    end
  end
end


#
# Parser for commanline options
#
class CommandParser

   def initialize
     @options = {}
   end
   
   def set_log_level(log_level)
    if ! log_level.nil?
       case log_level
       when "DEBUG"
         @options[:log_level] = Logger::DEBUG
       when "INFO"
         @options[:log_level] = Logger::INFO
       when "WARN"
         @options[:log_level] = Logger::WARN
       when "ERR"
         @options[:log_level] = Logger::ERROR
       end
     else
       @options[:log_level] = Logger::INFO
     end
   end

   def parse(args)
     @options[:log_level] = Logger::INFO
     optparse = OptionParser.new do |opts|
       opts.banner = "Usage: load.rb [options]"

       opts.separator ""

       opts.on("-N", "--nb-childreen ",
       "Number of children to run") do |arg|
         @options[:nb_children] = arg
       end

       opts.on("-D", "--output-directory ",
       "Output directory") do |arg|
         @options[:output_directory] = arg
       end

       opts.on("-M", "--nb-iterations ",
       "Nunmber of iterations for each child") do |arg|
         @options[:nb_iterations] = arg
       end
       
       opts.on("-S", "--server-ip ",
        "Usage server IP ") do |arg|
          @options[:server_ip] = arg
       end
        
      opts.on("-P", "--server-port ",
         "Usage server IP ") do |arg|
           @options[:server_port] = arg
       end
       
       opts.on("-L", "--log-level LOG_LEVEL", "Specifies log level") do |l| 
         set_log_level(l) 
       end
     end

     optparse.parse!(args)
   end

   def run
     logger = Logger.new(STDOUT)
     logger.level = @options[:log_level]
     logger.info("Start with  server_ip = #{@options[:server_ip]}, server_port = #{@options[:server_port]}, nb_children=#{@options[:nb_children]}, log_level = #{@options[:log_level]}, output_directory = #{@options[:output_directory]}, nb_iterations = #{@options[:nb_iterations]}")
     parent = Parent.new(logger, @options[:server_ip], @options[:server_port], @options[:nb_children], @options[:output_directory], @options[:nb_iterations])
     parent.run
   end
end


#
# Start parent and run test
#
parser = CommandParser.new
parser.parse(ARGV)
parser.run


