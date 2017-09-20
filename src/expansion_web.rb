require 'sinatra'
require 'date'

class ExpansionWeb < Sinatra::Base
  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
  end

  not_found do
    'Error 404 - Page Not Found'
  end

  error do
    'Error 500 - Sorry there was an error'
  end

  get '/' do
    "Hello #{settings.environment}!"
  end

  get '/expand' do
    erb :expansion_form
  end

  post '/expand/submit' do
    # create temporary directory logging time and IP
    timestamp = DateTime.now.to_s.gsub(":", "+")
    ip = request.ip.gsub(":", "+") # just in case we're on the loop back interface    
    d = Dir.mktmpdir "#{timestamp}_#{ip}" # TODO don't put this in var!

    # create files with provided info
    shell = File.new(File.join(d, "shell"), File::CREAT|File::TRUNC|File::WRONLY, 0644)
    env   = File.new(File.join(d, "env"), File::CREAT|File::TRUNC|File::WRONLY, 0644)
    user  = File.new(File.join(d, "users"), File::CREAT|File::TRUNC|File::WRONLY, 0644)

    # write files
    shell.write params['shell']
    shell.close
    
    JSON.parse(params['env']).each do |k, v|
      env.write "#{k}=#{v}\n"
    end
    env.close

    JSON.parse(params['users']).each do |u, d|
      user.write "#{u}=#{d}\n"
    end
    user.close
    
    "#{d} #{params['shell']} #{params['env']} #{params['users']}"
    
    # run expander for JSON
    #   /path/to/expand -env-file env -user-file users shell
    # catch error or send json out
  end
end
