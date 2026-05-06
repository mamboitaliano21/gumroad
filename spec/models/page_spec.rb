# frozen_string_literal: true

require "spec_helper"

describe Page do
  before do
    allow_any_instance_of(Pages::CompileTailwindService).to receive(:perform).and_return("/* stub */")
  end

  describe "validations" do
    it "requires raw_html" do
      page = build(:page, raw_html: nil)
      expect(page).not_to be_valid
      expect(page.errors[:raw_html]).to include("can't be blank")
    end

    it "rejects raw_html over 512 KB" do
      page = build(:page, raw_html: "x" * (Page::MAX_RAW_HTML_BYTES + 1))
      expect(page).not_to be_valid
      expect(page.errors[:raw_html].first).to match(/exceeds/)
    end

    it "accepts raw_html exactly at the cap" do
      page = build(:page, raw_html: "<div>" + ("x" * (Page::MAX_RAW_HTML_BYTES - 11)) + "</div>")
      expect(page).to be_valid
    end
  end

  describe "permalink generation" do
    it "assigns a permalink before validation" do
      page = build(:page, permalink: nil)
      page.valid?
      expect(page.permalink).to be_present
    end

    it "appends another character when single-char candidates are exhausted" do
      ("a".."z").each { |c| create(:page, permalink: c) }
      page = create(:page, permalink: nil)
      expect(page.permalink.length).to be >= 2
    end

    it "enforces uniqueness at the model layer" do
      create(:page, permalink: "uniq1")
      duplicate = build(:page, permalink: "uniq1")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:permalink]).to include("has already been taken")
    end
  end

  describe "sanitize and compile" do
    it "populates sanitized_html and compiled_css on save" do
      page = build(:page, raw_html: "<div class=\"text-red\"><script>x</script>safe</div>")
      page.save!
      expect(page.sanitized_html).not_to include("<script>")
      expect(page.sanitized_html).to include("safe")
      expect(page.compiled_css).to be_present
    end

    it "skips recompile on title-only updates" do
      page = create(:page, raw_html: "<div>original</div>")
      expect_any_instance_of(Pages::CompileTailwindService).not_to receive(:perform)
      page.update!(title: "Renamed")
    end

    it "recompiles when raw_html changes" do
      page = create(:page, raw_html: "<div>original</div>")
      expect_any_instance_of(Pages::CompileTailwindService).to receive(:perform).and_return("/* stub */")
      page.update!(raw_html: "<div>changed</div>")
    end

    it "adds an error and aborts save when CompileTailwindService raises" do
      allow_any_instance_of(Pages::CompileTailwindService)
        .to receive(:perform)
        .and_raise(Pages::CompileTailwindService::CompileError, "boom")
      page = build(:page, raw_html: "<div>x</div>")
      expect(page.save).to be false
      expect(page.errors[:raw_html].first).to match(/could not be compiled/)
    end
  end

  describe "soft delete" do
    it "marks deleted via Deletable concern" do
      page = create(:page)
      page.mark_deleted!
      expect(page.reload).to be_deleted
      expect(Page.alive).not_to include(page)
    end
  end
end
