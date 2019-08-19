require 'sinatra'
require "sinatra/config_file"
require 'date'

class SmooshWeb < Sinatra::Base
  register Sinatra::ConfigFile
  config_file 'config.yml'

  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
  end

  not_found do
    'Error 404 - Page not found'
  end

  error do
    'Error 500 - Sorry there was an error'
  end

  get '/' do
    erb :index
  end

  get '/shtepper' do
    @title = " - Shtepper"
    erb :shtepper
  end

  post '/shtepper' do
    require 'src/command'

    # remove illegal characters, drop carriage returns from combos
    script = params['shell'].scrub.encode({ universal_newline: true })

    # create temporary directory logging time and IP
    timestamp = DateTime.now.to_s.gsub(":", "+")
    ip = request.ip.gsub(":", "+") # just in case we're on the loop back interface
    d = Dir.mktmpdir("#{timestamp}_#{ip}_", settings.submissions_tmpdir)

    # create files with provided info
    shell  = File.new(File.join(d, "shell"), File::CREAT|File::TRUNC|File::WRONLY, 0644)
    env    = File.new(File.join(d, "env"),   File::CREAT|File::TRUNC|File::WRONLY, 0644)
    user   = File.new(File.join(d, "users"), File::CREAT|File::TRUNC|File::WRONLY, 0644)
    log    = File.new(File.join(d, "log"),   File::CREAT|File::TRUNC|File::WRONLY, 0644)

    # write files
    shell.write script
    shell.close

    JSON.parse(params['env']).each do |k, v|
      env.write "#{k}=#{v}\n"
    end
    env.close

    JSON.parse(params['users']).each do |u, d|
      user.write "#{u}=#{d}\n"
    end
    user.close

    # run shtepper for JSON
    #   /path/to/shtepper -env-file env -user-file users shell
    shtepper = Command.new(settings.shtepper_executable, 
                         '-env-file', File.path(env), 
                         '-user-file', File.path(user), 
                         File.path(shell))
    result = shtepper.execute!

    log.write result
    log.close

    if request.ip == "127.0.0.1" 
      File.delete(shell, env, user, log)
      Dir.rmdir d
    end

    if result[:exit_code].zero?
      result[:stdout]
    else
      "[{ \"error\": #{result[:stderr].dump} }]"
    end
  end
end
