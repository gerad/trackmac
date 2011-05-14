#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'appscript'
require 'sqlite3'
require 'eventmachine'
require 'uri'

class TrackMac
  def initialize
    @start = @now = Time.now
    @activity = 'started'
    setup_db!
  end

  def track!
    last = @now
    @now = Time.now
    @start ||= @now
    idle = idle_seconds

    last_activity = @activity
    @activity, finish =
      if @now - last > 5 # asleep
        ['asleep', last]
      elsif idle > 5 * 60 # idle
        ['idle', [@now - idle, 0].max]
      else
        [current_activity, @now]
      end

    if @activity != last_activity
      record_activity! @start, finish, last_activity
      @start = finish
    end
  end

  private
    def record_activity! start, finish, activity
      seconds = finish - start
      @db.execute("INSERT INTO trackmac VALUES (datetime(:start), datetime(:finish), :seconds, :activity)",
        :start => start.iso8601, :finish => finish.iso8601,
        :seconds => seconds, :activity => activity)
      puts "#{start.strftime("%H:%M:%S")} : #{'%3.1f' % seconds}s : #{activity}"
    end

    def setup_db!
      @db = SQLite3::Database.new('trackmac.db')
      create_table! unless table_exists?
    end

    def table_exists?
      !! @db.get_first_row('SELECT name FROM sqlite_master WHERE name=?', 'trackmac')
    end

    def create_table!
      @db.execute <<-SQL
        CREATE TABLE trackmac (
          start         TEXT,
          finish        TEXT,
          seconds       REAL,
          activity      TEXT
        )
      SQL
    end

    def current_activity
      # http://stackoverflow.com/questions/480866/get-the-title-of-the-current-active-window-document-in-mac-os-x
      frontmost = Appscript.app('System Events').application_processes.get.select{ |a| a.frontmost.get }.first rescue nil

      activity = []
      if frontmost
        name = frontmost.name.get rescue nil
        activity.unshift name

        if (frontmost.windows.count rescue 0) > 0
          window_name = frontmost.windows.first.name.get rescue nil
          activity.unshift window_name

          # Chrome Active Tab
          # http://stackoverflow.com/questions/2483033/get-the-url-of-the-frontmost-tab-from-chrome-on-os-x
          if name == 'Google Chrome'
            tab = Appscript.app('Google Chrome').windows.first.active_tab rescue nil
            tab_name = tab.name.get rescue nil
            tab_url = tab.URL.get rescue nil
            tab_domain = URI.parse(tab_url).host rescue nil

            activity.unshift tab_name, tab_domain, tab_url
          end
        end
      end

      activity.compact.join(" - ") || 'unknown'
    end

    def idle_seconds
      # http://www.dssw.co.uk/sleepcentre/threads/system_idle_time_how_to_retrieve.html
      %x(ioreg -c IOHIDSystem).split("\n").grep(/Idle/).last.split(/\s+/).last.to_i / 1000000000.0
    end
end

EventMachine::run do
  tm = TrackMac.new
  EventMachine::add_periodic_timer 1 do
    tm.track!
  end
end
