#!/usr/bin/env ruby
# created 08.09.03(wed)-11:25 kuraku
# $Id: gyofu.rb 21 2008-09-15 14:03:05Z masuda $

require 'gtk2'
require 'rexml/document'
require 'time'
require(File.expand_path(File.join(File.dirname(__FILE__), 'twtwsr-api')))

TWITTER = "twitter.com"
TENTRYMAX = 140

WASSR = "api.wassr.jp"
WENTRYMAX = 255

PROG_NAME = "GyoFu.rb"

# date format
WDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
MONTH = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
DFORMAT = "%m/%d %H:%M"

# res format
# [screen_name]:text (m/d H:M)
REPLY = "[%s] %s(@%s)：「%s」 %s\n"

## for debug
def debug(msg)
#   puts msg
end

## load properties
$prop = {}
propfile = "prop.xml"
propfile = File.expand_path(File.join(File.dirname(__FILE__), propfile))

xml = nil
File.open(propfile) {|xmlfile|
   xml = REXML::Document.new(xmlfile)
}

$prop['since_hour'] = xml.root.elements['since_hour'].text.to_i
$prop['replies_cnt'] = xml.root.elements['replies_cnt'].text.to_i
$prop['check_replies'] = xml.root.elements['check_replies'].text.to_s
$prop['silent'] = xml.root.elements['silent'].text.to_s

['Twitter','Wassr'].each { |sv|
   xml.root.each_element(sv) { |s|
      $prop[sv] = { 'user' => s.elements['user'].text, 'passwd' => s.elements['passwd'].text}
   }
}
debug("tuser: #{$prop['Twitter']['user']}")
debug("wuser: #{$prop['Wassr']['user']}")

# replies_cache
$cache = {}

# icon
iconfile = "maguro.gif"
iconfile = File.expand_path(File.join(File.dirname(__FILE__), iconfile))

# window
window = Gtk::Window.new
window.title = "GyoFu"
window.set_size_request(420, 140)
window.border_width = 10
window.set_icon(iconfile)
window.signal_connect("destroy") { Gtk.main_quit }

vbox = Gtk::VBox.new(false, 0)
window.add(vbox)

entry = Gtk::Entry.new
entry.max_length = 255
entry.text = ""
entry.select_region(0, -1)
vbox.pack_start(entry, false, false, 0)

hbox = Gtk::HBox.new(true, 0)
vbox.pack_start(hbox, false, false, 0)

# twitter
tcheck = Gtk::CheckButton.new("Twitter (#{$prop['Twitter']['user']}) #{TENTRYMAX}")
tapi = nil
# wassr
wcheck = Gtk::CheckButton.new("Wassr (#{$prop['Wassr']['user']}) #{WENTRYMAX}")
wapi = nil

tcheck.signal_connect("toggled") { |w|
   if w.active? || wcheck.active?
      entry.editable = true
   else
      entry.editable = false
   end
}
tcheck.active = entry.editable?
hbox.pack_start(tcheck, false, false, 8)

wcheck.signal_connect("toggled") { |w|
   if w.active? || tcheck.active?
      entry.editable = true
   else
      entry.editable = false
   end
}
wcheck.active = entry.editable?
hbox.pack_start(wcheck, false, false, 8)

## entry text size check
window.signal_connect("key-release-event") {
   len = entry.text.split(//).size
   if tcheck.active?
      tzan = TENTRYMAX - len
      tcheck.label =  "Twitter (#{$prop['Twitter']['user']}) #{tzan}"
   end

   if wcheck.active?
      wzan = WENTRYMAX - len
      wcheck.label =  "Wassr (#{$prop['Wassr']['user']}) #{wzan}"
   end
   #debug("entry size t:#{tzan} w:#{wzan}")
}

####
scroll = Gtk::ScrolledWindow.new
scroll.border_width = 2
scroll.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_ALWAYS)
scroll.set_window_placement(Gtk::CORNER_TOP_LEFT)
scroll.set_border_width(1)
scroll.set_shadow_type(Gtk::SHADOW_IN)
vbox.add(scroll)

log = Gtk::TextView.new()
log.set_size_request(180, 60)
log.set_wrap_mode(Gtk::TextTag::WRAP_CHAR)
log.set_can_focus(false)
log.editable = false
log.cursor_visible = false
scroll.add(log)

if($prop['check_replies'] == 'true')
   post_res_btn = "Post/Res"
else
   post_res_btn = "Post"
end
button = Gtk::Button.new(post_res_btn)
button.signal_connect("clicked") {
   wtpost(entry.text,tcheck,wcheck,entry,log,tapi,wapi)
}
hbox.pack_start(button, false, true, 5)
button.can_default = true

## post exec
def wtpost(status,tcheck,wcheck,entry,log,tapi,wapi)

   debug("#{status}")
   ok_flg = false;
   log.editable = true

   logs = log.buffer.get_text()

   log_text = ''

   if wcheck.active? && entry.text != ''
      log_text << "w"
   end
   if tcheck.active? && entry.text != ''
      log_text << "t"
   end

   log_text << ">> #{status}\n" if entry.text != ''

   ## since hour
   hour = Time.now
   hour = hour - (3600 * $prop['since_hour'])
   since_epoch = hour.to_i
   ## Thu, 24 Apr 2008 16:10:01 +0900
   since = hour.strftime("#{WDAYS[hour.wday]}, %d #{MONTH[hour.month-1]} %Y %T +0900")

   ## twitter
   ##
   if tcheck.active?
      if tapi == nil
         tapi = TwtwsrApi.new($prop['Twitter']['user'], $prop['Twitter']['passwd'], TWITTER)
      end

      if entry.text != ''
         tres = tapi.update(status)
         debug("twitter res:#{tres}")
         if tres.is_a? Net::HTTPOK
            ok_flg ||= true;
            if($prop['silent'] != 'true')
               log_text << "twitter: post ok\n"
            end
         else
            log_text << "twitter: post ng\n"
         end
      end

      ## reply
      if($prop['check_replies'] == 'true')
         tres = tapi.replies()
         ## tres = tapi.replies(since)
         debug("twitter res:#{tres}")
         if tres.is_a? Net::HTTPOK
            ok_flg ||= true;

            ## parse xml
            if($prop['silent'] != 'true')
               log_text << "* twitter replies\n"
            end
            # log_text << "twitter reply: #{tres.message}\n"
            txml = REXML::Document.new tres.body

            cnt = $prop['replies_cnt']

            txml.elements.each('statuses/status'){ |e|
               break if since_epoch >= Time.parse(e.elements['created_at'].text.to_s).to_i

               ## cache check
               debug("cache:#{$cache}\n")
               cachekey ="T-#{e.elements['user/screen_name'].text.to_s}-#{e.elements['created_at'].text.to_s}"

               if $cache[cachekey] == true
                  debug("cache break")
                  next
               else
                  $cache[cachekey] = true
               end
               debug("cache end:#{$cache}\n")

               replies = sprintf(REPLY,"T",
                                 e.elements['user/name'].text.to_s,
                                 e.elements['user/screen_name'].text.to_s,
                                 e.elements['text'].text.to_s,
                                 Time.parse(e.elements['created_at'].text.to_s).strftime(DFORMAT) )
               replies.sub!("@#{$prop['Twitter']['user']} ","")
               log_text << replies

               cnt = cnt - 1
               break if cnt <= 0
            }
         else
            log_text << "twitter: res check ng\n"
         end
      end
   end

   ## wassr
   ##
   if wcheck.active?
      if wapi == nil
         wapi = TwtwsrApi.new($prop['Wassr']['user'], $prop['Wassr']['passwd'], WASSR)
      end

      if entry.text != ''
         wres = wapi.update(status)
         debug("wassr res:#{wres}")
         if wres.is_a? Net::HTTPOK
            ok_flg ||= true;
            if($prop['silent'] != 'true')
               log_text << "wassr: post ok\n"
            end
         else
            log_text << "wassr: post ng\n"
         end
      end

      ## reply
      if($prop['check_replies'] == 'true')
         wres = wapi.replies()
         # wres = wapi.replies(since)
         debug("wassr res:#{wres}")
         if wres.is_a? Net::HTTPOK
            ok_flg ||= true;

            ## parse xml
            if($prop['silent'] != 'true')
               log_text << "* wassr replies\n"
            end
            # log_text << "wassr reply: #{wres.message}\n"
            wxml = REXML::Document.new wres.body

            cnt = $prop['replies_cnt']

            wxml.elements.each('statuses/status'){ |e|
               break if since_epoch >= e.elements['epoch'].text.to_i

               ## cache check
               debug("cache:#{$cache}\n")
               cachekey = "W-#{e.elements['user_login_id'].text.to_s}-#{e.elements['epoch'].text.to_s}"

               if $cache[cachekey] == true
                  debug("cache break")
                  next
               else
                  $cache[cachekey] = true
               end
               debug("cache end:#{$cache}\n")

               replies = sprintf(REPLY, "W",
                                 e.elements['user/screen_name'].text.to_s,
                                 e.elements['user_login_id'].text.to_s,
                                 e.elements['text'].text.to_s,
                                 Time.at(e.elements['epoch'].text.to_i).strftime(DFORMAT))
               replies.sub!("@#{$prop['Wassr']['user']} ","")
               log_text << replies

               cnt = cnt - 1
               break if cnt <= 0
            }
         else
            log_text << "wassr: res check ng\n"
         end
      end
   end

   ## post or res check OK
   ##
   if ok_flg
      debug("POST OK")
      nowtime = Time.new()
      nowtime = nowtime.strftime("#{WDAYS[nowtime.wday]}, %d #{MONTH[nowtime.month-1]} %Y %T")
      nowtime_s = Time.new()
      nowtime_s = nowtime_s.strftime("%H:%M")
      if($prop['silent'] == 'true')
         log_text << "## #{nowtime_s}\n"
      else
         log_text << "## #{nowtime} ok ##########\n"
      end
      entry.text = "";
      entry.grab_focus
      tcheck.label = "Twitter (#{$prop['Twitter']['user']}) #{TENTRYMAX}"
      wcheck.label = "Wassr (#{$prop['Wassr']['user']}) #{WENTRYMAX}"
   end

   ## log rewrite
   log_text << log.buffer.get_text()
   log.buffer.set_text(log_text)

   log.editable = false
end

## display
window.show_all

Gtk.main
