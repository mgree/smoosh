require 'childprocess'
require 'tempfile'

class Command
  attr_reader :argv
  attr_accessor :timeout
  attr_accessor :environment

  def initialize(*argv)
    @argv = argv

    @process = ChildProcess.build(*@argv)

    @stdout = Tempfile.new('stdout').tap { |io| io.sync = true }
    @stderr = Tempfile.new('stderr').tap { |io| io.sync = true }

    @process.io.stdout = @stdout
    @process.io.stderr = @stderr
  end

  def execute!
    run_process!

    @stdout.rewind
    @stderr.rewind

    process_data = {
      stdout: @stdout.read,
      stderr: @stderr.read,
      exit_code: @process.exit_code,
      duration: @duration,
    }

    return process_data
  ensure
    @stdout.close
    @stderr.close
  end

  protected

  def run_process!
    command_string = argv.join(' ')

    start_time = Time.now
    begin
      @process.start
    rescue ChildProcess::LaunchError => e
      raise ("Failed to execute '%{command}': %{message}" % { command: command_string, message: e.message })
    end

    if timeout
      begin
        @process.poll_for_exit(timeout)
      rescue ChildProcess::TimeoutError
        @process.stop
      end
    else
      @process.wait
    end

    @duration = Time.now - start_time
  end
end
