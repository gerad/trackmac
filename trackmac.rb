require 'rubygems'
require 'bundler/setup'
require 'appscript'

# http://stackoverflow.com/questions/480866/get-the-title-of-the-current-active-window-document-in-mac-os-x
def self.current_activity
  frontmost = Appscript.app('System Events').application_processes.get.select{ |a| a.frontmost.get }.first

  activity = []
  if !frontmost
    activity << 'unknown'
  else
    activity << frontmost.name.get

    if frontmost.windows.count > 0
      window = frontmost.windows.first
      activity << window.name.get

      # Chrome Active Tab
      # http://stackoverflow.com/questions/2483033/get-the-url-of-the-frontmost-tab-from-chrome-on-os-x
      if frontmost.name.get == 'Google Chrome'
        tab = Appscript.app('Google Chrome').windows[0].active_tab
        activity << tab.name.get
        activity << tab.URL.get
      end
    end
  end

  activity.compact.join(" - ")
end

start = finish = last = now = Time.now
activity = last_activity = 'started'
while true
  last = now
  now = Time.now
  start ||= now

  # http://www.dssw.co.uk/sleepcentre/threads/system_idle_time_how_to_retrieve.html
  idle = %x(ioreg -c IOHIDSystem).split("\n").grep(/Idle/).last.split(/\s+/).last.to_i / 1000000000.0

  last_activity = activity
  activity, finish =
    if now - last > 5 # asleep
      ['asleep', last]
    elsif idle > 5 * 60 # idle
      ['idle', now - idle]
    else
      [current_activity, now]
    end

  if activity != last_activity
    puts "#{start.strftime("%H:%M:%S")} : #{'%3.1f' % (finish - start)}s : #{last_activity}"
    start = finish
  end

  sleep 1
end
