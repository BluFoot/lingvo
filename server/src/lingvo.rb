require 'thin'
require 'sinatra/base'
require 'em-websocket'
require 'google/cloud/translate'
require 'htmlentities'

translate = Google::Cloud::Translate.new project: 'translate-187816'

class App < Sinatra::Base
  set :root, '../client'

  get '/' do
    erb :index
  end
end

def ws_send(ws, type, data)
  ws.send({type: type, data: data}.to_json)
end

EventMachine.run do
  @clients = []

  EM::WebSocket.start(host: '0.0.0.0', port: 3002) do |ws|
    ws.onopen do
      @clients << ws
      languages = translate.languages "en"
      msg = languages.map { |l| {value: l.code, text: l.name} }
      ws_send ws, 'languages', msg
    end

    ws.onclose do
      @clients.delete ws
    end

    ws.onmessage do |msg|
      data = JSON.parse(msg)
      puts "Received Message: #{data}"
      translations = data['to'].map do |to|
        translate.translate data['text'], to: to, from: data['from']
      end.map do |translation|
        HTMLEntities.new.decode translation.text
      end
      ws_send ws, 'translations', translations
    end
  end

  # App.run! port: 3001
  Thin::Server.start('0.0.0.0', 3001, App.new, signals: false)
end