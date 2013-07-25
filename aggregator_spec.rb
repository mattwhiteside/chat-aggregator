require 'rspec'
require "#{File.dirname(__FILE__)}/chat_aggregator"



describe 'Chat Aggregation' do
  before(:all) do
    @aggregator = ChatAggregator.new
    @aggregator.add_event ChatAggregator::Event.new ChatAggregator::ENTRY, DateTime.new(2013,7,24,17,31,30), "Ralph"
    @aggregator.add_event ChatAggregator::Event.new ChatAggregator::COMMENT, DateTime.new(2013,7,24,17,31,36), "Lisa", nil, "Hi Ralph"
    @aggregator.add_event ChatAggregator::Event.new ChatAggregator::COMMENT, DateTime.new(2013,7,24,17,31,41), "Ralph", nil, "Hi Lisa"

  end
  it 'should aggregate properly for one interval' do
    buckets = @aggregator.aggregate DateTime.new(2013,7,24,17,0,0), ONE_HOUR
    buckets.size.should == 1
    interval_start, summary = buckets[0][0], buckets[0][1]
    summary.keys.size.should == 2
    summary.should have_key(ChatAggregator::ENTRY)
    summary.should have_key(ChatAggregator::COMMENT)
    summary[ChatAggregator::COMMENT].should == 2
    #To change this template use File | Settings | File Templates.

  end

  it 'should aggregate properly across 2 intervals' do
    @aggregator.add_event ChatAggregator::Event.new ChatAggregator::HIGH_FIVE, DateTime.new(2013,7,24,18,2,30), "Ralph", "Lisa"
    @aggregator.add_event ChatAggregator::Event.new ChatAggregator::EXIT, DateTime.new(2013,7,24,18,2,36), "Ralph"
    @aggregator.add_event ChatAggregator::Event.new ChatAggregator::COMMENT, DateTime.new(2013,7,24,18,3,12), "Moe", nil, "What's it to ya?"
    @aggregator.add_event ChatAggregator::Event.new ChatAggregator::COMMENT, DateTime.new(2013,7,24,18,10,19), "Homer", nil, "One flaming moe please"
    buckets = @aggregator.aggregate DateTime.new(2013,7,24,17,0,0), ONE_HOUR
    buckets.size.should == 2
    interval_start, summary = buckets[1][0], buckets[1][1]
    summary.keys.size.should == 3
    summary.should_not have_key(ChatAggregator::ENTRY)
    summary.should have_key(ChatAggregator::EXIT)
    summary[ChatAggregator::COMMENT].should == 2
  end

  it "should produce aggregated totals which add to the total number of events" do
    buckets = @aggregator.aggregate DateTime.new(2013,7,24,17,0,0), ONE_HOUR
    total = 0
    buckets.each do |bucket|
      summary_hash = bucket[1]
      summary_hash.each do |k,val|
        total += val
      end
    end
    total.should == @aggregator.events.size
  end

end