require 'date'

unless defined? ONE_HOUR#silence warnings
  ONE_HOUR = 60 * 60
  ONE_DAY = 24 * ONE_HOUR
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

  #in a real use case, this class would provide a way to intake the event data from an external source,
  #but for these purposes, I'm just populating it with test data
  def initialize
    generate_mock_data
  end

  def aggregate(start_time, interval)
    range = start_time..(start_time + interval)
    @buckets = [[range.first,{}]]
    @events.each do |event|
      current_bucket = @buckets.last
      unless range.cover? event.timestamp
        range = (range.first + interval)..(range.last + interval)
        @buckets << [range.first, {}]
      end
      current_bucket[1][event.event_type] ||= 0
      current_bucket[1][event.event_type] += 1
    end
    @buckets
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

  end

private
  def generate_mock_data
    @events = []
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
      interval = rand(300) / ONE_DAY.to_f
      timestamp += interval
      instigator = names[rand(names.size)]
      if event_type == ChatAggregator::HIGH_FIVE
        until !receiver.nil? && receiver != instigator
          receiver = names[rand(names.size)]
        end
      elsif event_type == ChatAggregator::COMMENT
        content = comments[rand(comments.size)]
      end

      @events << Event.new(event_type, timestamp, instigator, receiver, content)
    end
    @events.freeze
  end


end

if __FILE__ == $0
  #puts "command line interface here"
  #transcriber = ChatAggregator.new
else
  require 'sinatra'
  require 'sinatra/reloader'

  class ChatTranscriptViewer < Sinatra::Base

    configure :development do
      register Sinatra::Reloader
    end

    get '/' do
      @transcriber ||= ChatAggregator.new

      #didn't want this code to have a lot of dependencies,
      # so I'm doing the display logic here, in order
      # to avoid adding a view templating engine and to
      # keep the number of files small
      granularity = params[:granularity]
      _response = case granularity
                    when /hourly|daily/
                      td_style = "style='border: 1px solid black; padding: 5mm;'"
                      start_time = @transcriber.events.first.timestamp

                      time_format = if granularity == 'hourly'
                                      rounded_start_time = start_time - start_time.minute * 60 - start_time.second
                                      "%I %p"
                                    else
                                      rounded_start_time = start_time - start_time.hour * ONE_HOUR - start_time.minute * 60 - start_time.second
                                      "%a %b %d, %Y"
                                    end

                      table = "<table>"
                      @transcriber.aggregate(rounded_start_time, ONE_HOUR).each do |bucket|
                        time = bucket[0]
                        event_totals = bucket[1]
                        summaries = []
                        if !(num_events = event_totals[ChatAggregator::ENTRY]).nil? && num_events > 0
                          summaries << case num_events
                                         when 1
                                           "1 person entered"
                                         else
                                           "#{num_events} people entered"
                                       end
                        end

                        if !(num_events = event_totals[ChatAggregator::EXIT]).nil? && num_events > 0
                          summaries << case num_events
                                         when 1
                                           "1 person left"
                                         else
                                           "#{num_events} people left"
                                       end
                        end

                        if !(num_events = event_totals[ChatAggregator::COMMENT]).nil? && num_events > 0
                          summaries << case num_events
                                         when 1
                                           "1 comment"
                                         else
                                           "#{num_events} comments"
                                       end
                        end

                        if !(num_events = event_totals[ChatAggregator::HIGH_FIVE]).nil? && num_events > 0
                          summaries << case num_events
                                         when 1
                                           "1 high-five was exchanged"
                                         else
                                           "#{num_events} high-fives were exchanged"
                                       end
                        end

                        table += "<tr valign=top><td #{td_style}>#{time.strftime(time_format)}</td><td #{td_style}>" +
                                 "#{summaries.join("<br /><br />")}</td>" +
                                 "</tr>"
                      end
                      table + "</table>"
                    when 'daily'
                      start_time = @transcriber.events.first.timestamp
                      rounded_start_time = start_time - start_time.minute * 60 - start_time.second
                      @transcriber.aggregate rounded_start_time, ONE_DAY
                    else

                      @transcriber.events.inject("") do |out, event|
                        time = event.timestamp.strftime("%I:%M%p").downcase
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

  end

end
