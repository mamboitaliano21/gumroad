# frozen_string_literal: true

require "open3"

module Pages
  class CompileTailwindService
    class CompileError < StandardError; end

    SCRIPT_PATH = Rails.root.join("script/pages/tailwind_compile.mjs").to_s
    TIMEOUT_SECONDS = 10

    def initialize(html)
      @html = html.to_s
    end

    def perform
      Timeout.timeout(TIMEOUT_SECONDS) do
        stdout, stderr, status = Open3.capture3("node", SCRIPT_PATH, stdin_data: @html)
        raise CompileError, stderr.presence || "tailwind compile exited #{status.exitstatus}" unless status.success?
        stdout
      end
    rescue Timeout::Error
      raise CompileError, "tailwind compile exceeded #{TIMEOUT_SECONDS}s"
    end
  end
end
