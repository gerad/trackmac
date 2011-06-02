require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/content_for'
require 'sequel'
require 'haml'

class Date
  def to_time
    Time.new(year, month, day)
  end
end

DB = Sequel.connect('sqlite://trackmac.db')
class Event < Sequel::Model(:trackmac)
  def start; parse_time(:start) end
  def finish; parse_time(:finish) end
  def seconds; self[:seconds].to_f end

  def hour; self.start.strftime('%H').to_i end
  def minute; self.start.strftime('%M').to_i end

  def self.for_day(day_str=nil)
    day = (day_str ? Date.parse(day_str) : Date.today).to_time
    self.filter("datetime(start) BETWEEN datetime(:day) AND datetime(:day, '+1 day')", :day => day.iso8601)
  end

  private
    def parse_time(attr)
      Time.parse(self[attr] + 'Z').localtime
    end
end

get '/' do
  @events = Event.for_day(params[:day]).order(:start)
  haml :index
end
