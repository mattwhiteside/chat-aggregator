require 'date'
require 'csv'


unless defined? ONE_HOUR#silence warnings
  ONE_DAY = 1
  ONE_HOUR = ONE_DAY/24.to_f
  ONE_MINUTE = ONE_HOUR / 60
  ONE_SECOND = ONE_MINUTE / 60

end

class ChatAggregator

  unless defined? HIGH_FIVE
    HIGH_FIVE = :high_five
    ENTRY = :entry
    EXIT = :exit
    COMMENT = :comment
    EVENT_TYPES = [HIGH_FIVE, ENTRY, EXIT, COMMENT].freeze
  end

  attr_reader :events

  def self.gen_mock_data
    CSV.open("#{File.dirname(__FILE__)}/mock_data.csv", "wb") do |csv|
      timestamp = DateTime.new(2013,7,21,12,5,21)

      #here is our sample data:
      names = %w{Ralph Barney Homer Marge Lisa Waylon Wendall Lionel Uder Kearny Nelson Troy Edna Doris}
      comments = ["Hiya Homah",
                  "Doh!",
                  "Excellent",
                  "sleep: that's where I'm a real viking",
                  "i don't feel right",
                  "My cat's name is mittens",
                  "Where's the any key?",
                  "I think I'll just order a tab"]



      200.times do
        event_type = ChatAggregator::EVENT_TYPES[rand(ChatAggregator::EVENT_TYPES.size)]
        receiver, content = nil, nil
        minutes = rand() * ONE_HOUR
        days = minutes / ONE_DAY
        timestamp += days
        instigator = names[rand(names.size)]
        if event_type == ChatAggregator::HIGH_FIVE
          until !receiver.nil? && receiver != instigator
            receiver = names[rand(names.size)]
          end
        elsif event_type == ChatAggregator::COMMENT
          content = comments[rand(comments.size)]
        end
        csv << [event_type, timestamp, instigator, receiver, content]

      end

    end

  end

  def initialize
    @events = []
  end


  def aggregate(start_time, interval)
    range = start_time..(start_time + interval)
    buckets = [[range.first,{}]]
    current_bucket = buckets.last
    @events.each do |event|
      unless range.cover? event.timestamp
        range = (range.first + interval)..(range.last + interval)
        buckets << [range.first, {}]
        current_bucket = buckets.last
      end
      current_bucket[1][event.event_type] ||= 0
      current_bucket[1][event.event_type] += 1
    end
    buckets
  end

  class Event

    attr_reader :event_type
    attr_reader :timestamp
    attr_reader :instigator #username; assuming for simplicity that usernames
                            #are unique for the chatroom
    attr_reader :receiver	#username
    attr_reader :content

    def initialize(event_type, timestamp, instigator, receiver = nil, content = nil)
      @event_type, @timestamp = event_type, timestamp
      @instigator, @receiver = instigator, receiver
      @content = content
    end

    def to_s
      "#{@timestamp} - #{@event_type}"
    end

  end



  def read_mock_data
    CSV.foreach("#{File.dirname(__FILE__)}/mock_data.csv", "r") do |csv|
      type = csv[0].to_sym
      timestamp = DateTime.strptime(csv[1])
      instigator = csv[2]
      receiver = csv[3]
      content = csv[4]
      @events << Event.new(type, timestamp, instigator, receiver, content)
    end
  end

  def add_event(event)
    @events << event
  end


end

if __FILE__ == $0
  puts "generating mock data..."
  ChatAggregator.gen_mock_data
  puts "successfully generated mock data"
else
  require 'sinatra'
  require 'sinatra/reloader'

  class ChatTranscriptViewer < Sinatra::Base




    get '/' do
      @aggregator ||= ChatAggregator.new
      @aggregator.read_mock_data
      td_style = "style='border: 1px solid black; padding: 5mm;'"
      start_time = @aggregator.events.first.timestamp

      #didn't want this code to have a lot of dependencies,
      # so I'm doing the display logic here, in order
      # to avoid adding a view templating engine and to
      # keep the number of files small
      granularity = params[:granularity]
      _response = case granularity
                    when 'hourly'

                      time_format = "%-I %p"
                      rounded_start_time = start_time - start_time.minute * ONE_MINUTE - start_time.second * ONE_SECOND
                      table = "<table>"
                      @aggregator.aggregate(rounded_start_time, ONE_HOUR).each do |bucket|
                        time = bucket[0]
                        summary = render_summary(bucket)
                        table += "<tr valign=top><td #{td_style}>#{time.strftime(time_format)}</td><td #{td_style}>" +
                            "#{summary}</td>" +
                            "</tr>"
                      end
                      table + "</table>"

                    when 'daily'
                      time_format = "%a %b %-d, %Y"
                      rounded_start_time = start_time - start_time.hour * ONE_HOUR - start_time.minute * ONE_MINUTE - start_time.second * ONE_SECOND
                      table = "<table>"
                      @aggregator.aggregate(rounded_start_time, ONE_DAY).each do |bucket|
                        if bucket[1].keys.size > 0
                          time = bucket[0]
                          summary = render_summary(bucket)
                          table += "<tr valign=top><td #{td_style}>#{time.strftime(time_format)}</td><td #{td_style}>" +
                              "#{summary}</td>" +
                              "</tr>"
                        end
                      end
                      table + "</table>"

                    else

                      @aggregator.events.inject("") do |out, event|
                        time = event.timestamp.strftime("%-I:%M %p").downcase
                        summary = "#{event.instigator} " + case event.event_type
                                                             when ChatAggregator::ENTRY
                                                               "enters the room"
                                                             when ChatAggregator::EXIT
                                                               "leaves"
                                                             when ChatAggregator::HIGH_FIVE
                                                               "high-fives #{event.receiver}"
                                                             when ChatAggregator::COMMENT
                                                               "comments: \"#{event.content}\""
                                                             else
                                                               "UNKNOWN EVENT TYPE"
                                                           end
                        out += "#{time}: #{summary}<br /><br />"
                      end
                  end

      [200,{}, "<html><body>#{_response}</body></html>"]
    end

    private
    def render_summary(bucket)
      event_totals = bucket[1]
      summaries = []

       if !(entries = event_totals[ChatAggregator::ENTRY]).nil? && entries > 0
        summaries << case entries
                       when 1
                         "1 person entered"
                       else
                         "#{entries} people entered"
                     end
      end

      if !(exits = event_totals[ChatAggregator::EXIT]).nil? && exits > 0
        summaries << case exits
                       when 1
                         "1 person left"
                       else
                         "#{exits} people left"
                     end
      end

      if !(comments = event_totals[ChatAggregator::COMMENT]).nil? && comments > 0
        summaries << case comments
                       when 1
                         "1 comment"
                       else
                         "#{comments} comments"
                     end
      end

      if !(high_fives = event_totals[ChatAggregator::HIGH_FIVE]).nil? && high_fives > 0
        summaries << case high_fives
                       when 1
                         "1 high-five was exchanged"
                       else
                         "#{high_fives} high-fives were exchanged"
                     end
      end


      summaries.join("<br /><br />")
    end

  end

end