#!/usr/bin/env ruby
# frozen_string_literal: true

# chrono-manager: codegeass.ru chronology manager.
# Copyright (c) 2019 Sumeragi Kaguya <nyalice _at_ technologist.com>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

require 'json'
require 'net/http'

REQUESTS_PER_SECOND = 10

JS_ARRAY = 'weather_data.js'

WIND_DIRECTION_MAP = {
  'юго-восточный' => 0,
  'южный' => 1,
  'юго-западный' => 2,
  'западный' => 3,
  'северо-западный' => 4,
  'северно-западный' => 4,
  'северный' => 5,
  'северо-восточный' => 6,
  'восточный' => 7,
  'штиль' => 8
}.freeze

MOON_PHASE_MAP = {
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Moon30/lunar_eclipse.png' => 0,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Moon30/waxing_gibbous.png' => 1,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Moon30/first_quarter.png' => 2,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Moon30/waxing_crescent.png' => 3,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Moon30/full_moon.png' => 4,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Moon30/waning_gibbous.png' => 5,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Moon30/third_quarter.png' => 6,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Moon30/waning_crescent.png' => 7,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Moon30/new_moon.png' => 8
}.freeze

WEATHER_CARD_MAP = {
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/09.png' => 0,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/12.png' => 1,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/28.png' => 2,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/27.png' => 3,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/32.png' => 4,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/31.png' => 5,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/34.png' => 6,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/33.png' => 7,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/36.png' => 8,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/39.png' => 9,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/45.png' => 10,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/00.png' => 11,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/26.png' => 12,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/05.png' => 13,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/13.png' => 14,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/14.png' => 15,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/46.png' => 16,
  'http://rom-brotherhood.ucoz.ru/CodeGeass/Daily/41.png' => 17
}.freeze

def main
  data = {}
  day_pages = []

  previous = Time.at(0)

  Net::HTTP.start('codegeass.ru', use_ssl: true) do |http|
    link = 'https://codegeass.ru/pages/daily'

    response = nil
    until response.is_a? Net::HTTPOK
      delay = 1.0 / REQUESTS_PER_SECOND - (Time.now - previous)
      if delay.positive?
        pp "Sleeping for #{delay}"
        sleep delay
      end

      request = Net::HTTP::Get.new(
        link, { 'User-Agent' => 'PostmanRuntime/7.26.8' }
      )
      response = http.request request
      previous = Time.now

      next if response.is_a? Net::HTTPOK

      p 'Error!'
      pp response
      pp response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)
    end

    body = response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)
    body.each_line do |line|
      if (matches = line.scan(%r{
            <a\ href="?(https?://codegeass.ru/pages/20[0-9]+)"?>
        }x)).empty?
      # if (matches = line.scan(%r{
      #   <a\ href="?(https?://codegeass.ru/pages/20180201)"?>
      # }x)).empty?
        next
      end

      day_pages += matches.flatten
    end

    day_pages.each do |day_link|
      response = nil
      until response.is_a? Net::HTTPOK
        delay = 1.0 / REQUESTS_PER_SECOND - (Time.now - previous)
        if delay.positive?
          pp "Sleeping for #{delay}"
          sleep delay
        end

        request = Net::HTTP::Get.new(
          day_link, { 'User-Agent' => 'PostmanRuntime/7.26.8' }
        )
        response = http.request request
        previous = Time.now

        next if response.is_a? Net::HTTPOK

        p 'Error!'
        pp response
        pp response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)
      end

      body = response.body.encode(Encoding::UTF_8, Encoding::Windows_1251)

      year, month, day =
        /([0-9]{4})([0-9]{2})([0-9]{2})$/.match(day_link).captures
      # to_i.to_s allows to quickly get rid of leading 0
      month = month.to_i.to_s
      day = day.to_i.to_s

      day_table = (((data[year] ||= {}
                    )[month] ||= {}
                   )[day] ||= {})

      if !['7', '8'].include? month
        body.each_line do |line|
          unless (match = line.match(%r{
            <table\ width=900px\ border=1><tr>
              <td\ width=300px><h1><b><font\ size=4>
                <a\ name=[^>]+></a>(?<location>.+)
              </font></b></h1></td>
              .*
              <td\ width=30px>
                <img\ src="(?<moon_link>[^"]+)"\ title="[^"]+"\ alt="[^"]+">
              </td>
              .*
              <td\ width=410px>Восход:\ (?<sunrise>[0-9]+:[0-9]+),
                             \ Заход:\ (?<sunset>[0-9]+:[0-9]+),
                             \ Магнитное\ поле:\ (?:(?:слабо|сильно)\ )?
                                 (?<magnet>спокойное|возмущенное)
              </td>
          }x))
            next
          end

          location = match[:location]
          day_table[location] = {
            'moon' => MOON_PHASE_MAP[match[:moon_link]],
            'sunrise' => match[:sunrise],
            'sunset' => match[:sunset],
            'magnet' => match[:magnet] == 'возмущенное'
          }
          section_array = day_table[location]['time'] = []

          day_sections = line.scan(%r{
            <td\ width=90px>
              <img\ src="(?<weather_link>[^"]+)"\ title="[^"]+"\ alt="[^"]+"
                \ width=90px\ height=90px>
            </td>
            <td\ width=280px>
              (?:<br>)?<br>
              <b>[^<]+</b>
              <br><br>[^<]*<br>
              Температура\ воздуха:\ (?<temperature>[-+0-9]+)°С
              <br>
              Давление:\ (?<pressure>[0-9]+)\ мм.\ рт.\ ст.
              <br>
              Влажность:\ (?<humidity>[0-9]+)%
              <br>
              Ветер:\ (?<wind_direction>[^,]+),\ (?<wind_speed>[0-9]+)\ м/(?:с|c)
              <br>(?:<br>)?
            </td>
          }x)

          day_sections.each do |section_data|
            (weather_link, temperature, pressure, humidity, wind_direction,
             wind_speed) = section_data
            weather_card = (WEATHER_CARD_MAP[weather_link] ||
                            100 + weather_link[/([0-9]{2})\.png/, 1].to_i)
            section_array << {
              'card' => weather_card,
              'temp' => temperature.to_i,
              'merc' => pressure.to_i,
              'wet' => humidity.to_i,
              'windt' => WIND_DIRECTION_MAP[wind_direction],
              'windv' => wind_speed.to_i
            }
          end
        end
      else
        day_data = nil
        section_array = nil
        section_data = nil
        in_header = false
        in_sections = false

        body.each_line do |line|
          if (match = line.match(%r{
            <h1><b><font\ size=4>(?<location>.+)</font></b></h1>
          }x))
            day_data = day_table[match[:location]] = {}
            in_header = true
          elsif !in_sections && (match = line.match(/
            <img\ src="(?<moon_link>[^"]+)"\ title="[^"]+"\ alt="[^"]+">
          /x))
            day_data['moon'] = MOON_PHASE_MAP[match[:moon_link]]
          elsif !in_sections && (match = line.match(/
            Восход:\ +(?<sunrise>[0-9]+:[0-9]+),
            \ Заход:\ +(?<sunset>[0-9]+:[0-9]+),
            \ Магнитное\ поле:\ (?:(?:слабо|сильно)\ )?
                (?<magnet>спокойное|возмущенное)
          /x))
            day_data['sunrise'] = match[:sunrise]
            day_data['sunset'] = match[:sunset]
            day_data['magnet'] = match[:magnet] == 'возмущенное'
            in_sections = true
            section_array = day_data['time'] = []
          elsif in_sections && (match = line.match(/
            <img\ src="(?<weather_link>[^"]+)"\ title="[^"]+"\ alt="[^"]+"
              \ width=90px\ height=90px>
          /x))
            weather_card = (
              WEATHER_CARD_MAP[match[:weather_link]] ||
              100 + match[:weather_link][/([0-9]{2})\.png/, 1].to_i
            )
            section_data = {
              'card' => weather_card
            }
            section_array << section_data
          elsif in_sections && (match = line.match(/
            Температура\ воздуха:
              \ +(?:[-+0-9]+[^0-9]+)?
                 (?<temperature>[-+0-9]+)°С
          /x))
            section_data['temp'] = match[:temperature].to_i
          elsif in_sections && (match = line.match(/
            Давление:\ +(?<pressure>[0-9]+)\ мм.\ рт.\ ст.
          /x))
            section_data['merc'] = match[:pressure].to_i
          elsif in_sections && (match = line.match(/
            Влажность:\ +(?<humidity>[0-9]+)%
          /x))
            section_data['wet'] = match[:humidity].to_i
          elsif in_sections && (match = line.match(%r{
            Ветер:\ +(?<wind_direction>[^,<]+)
              (?:,\ +(?<wind_speed>[0-9]+)\ +м/(?:с|c))?
          }x))
            section_data['windt'] = WIND_DIRECTION_MAP[match[:wind_direction]]
            section_data['windv'] = match[:wind_speed].to_i
          elsif line.match(%r{</table>})
            if in_header
              in_header = false
            else
              in_sections = false
            end
          end
        end
      end
    end
  end

  File.open(JS_ARRAY, 'w') do |file|
    # print data.to_json(
    #   space: ' ', indent: '  ', object_nl: "\n", array_nl: "\n"
    # )
    # file.puts data.to_json(
    #   space: ' ', indent: '  ', object_nl: "\n", array_nl: "\n"
    # )
    file.puts data.to_json()
  end
end

main if $PROGRAM_NAME == __FILE__
