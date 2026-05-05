# frozen_string_literal: true

require "spec_helper"

describe Pages::CompileTailwindService do
  it "compiles Tailwind utility classes to CSS" do
    css = described_class.new("<div class=\"text-red-500 bg-blue-100 p-4\">x</div>").perform
    expect(css).to include("--color-red-500")
    expect(css).to include("--color-blue-100")
  end

  it "returns CSS even when no candidates are present" do
    css = described_class.new("<div>plain</div>").perform
    expect(css).to be_a(String)
  end

  it "raises CompileError when the script fails" do
    allow(Open3).to receive(:capture3).and_return(["", "boom", instance_double(Process::Status, success?: false, exitstatus: 1)])
    expect { described_class.new("<div>x</div>").perform }.to raise_error(Pages::CompileTailwindService::CompileError, /boom/)
  end

  it "raises CompileError when the subprocess exceeds TIMEOUT_SECONDS" do
    allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
    expect { described_class.new("<div>x</div>").perform }.to raise_error(
      Pages::CompileTailwindService::CompileError,
      /exceeded #{Pages::CompileTailwindService::TIMEOUT_SECONDS}s/o
    )
  end
end
