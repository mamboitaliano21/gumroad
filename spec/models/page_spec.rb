# frozen_string_literal: true

require "spec_helper"

describe Page do
  describe "associations" do
    it { is_expected.to belong_to(:seller).class_name("User").optional(false) }
  end

  describe "validations" do
    subject { build(:page) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(Page::TITLE_MAX_LENGTH) }
    it { is_expected.to validate_presence_of(:raw_html) }
    it { is_expected.to allow_value("abcd1234").for(:unique_permalink) }
    it { is_expected.not_to allow_value("abc-123").for(:unique_permalink) }
    it { is_expected.not_to allow_value("ABCD1234").for(:unique_permalink) }

    it "rejects a duplicate unique_permalink" do
      create(:page, unique_permalink: "abcd1234")
      duplicate = build(:page, unique_permalink: "abcd1234")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:unique_permalink]).to be_present
    end

    it "rejects raw_html exceeding CONTENT_MAX_BYTES" do
      page = build(:page, raw_html: "a" * (Page::CONTENT_MAX_BYTES + 1))
      expect(page).not_to be_valid
      expect(page.errors[:raw_html]).to be_present
    end

    it "auto-fills unique_permalink when blank" do
      page = build(:page, unique_permalink: nil)
      page.valid?
      expect(page.unique_permalink).to match(/\A[a-z0-9]{8}\z/)
    end
  end

  describe "permalink generation" do
    it "retries when the first candidate collides with an existing record" do
      create(:page, unique_permalink: "aaaaaaaa")
      allow(SecureRandom).to receive(:alphanumeric).with(Page::PERMALINK_LENGTH).and_return("AAAAAAAA", "BBBBBBBB")
      page = build(:page, unique_permalink: nil)
      page.valid?
      expect(page.unique_permalink).to eq("bbbbbbbb")
    end

    it "raises when no unique candidate is found within max_retries" do
      create(:page, unique_permalink: "aaaaaaaa")
      allow(SecureRandom).to receive(:alphanumeric).with(Page::PERMALINK_LENGTH).and_return("AAAAAAAA")
      expect { Page.generate_unique_permalink(max_retries: 2) }.to raise_error(/Failed to generate unique permalink/)
    end

    it "preserves an explicitly assigned unique_permalink" do
      page = build(:page, unique_permalink: "explicit")
      page.valid?
      expect(page.unique_permalink).to eq("explicit")
    end
  end

  describe "before_validation :resanitize" do
    it "fills sanitized_html by stripping disallowed tags from raw_html" do
      page = build(:page, raw_html: "<p>kept</p><script>alert(1)</script>", sanitized_html: nil)
      page.valid?
      expect(page.sanitized_html).to include("kept")
      expect(page.sanitized_html).not_to include("<script>")
      expect(page.sanitized_html).not_to include("alert(1)")
    end

    it "overwrites direct writes to sanitized_html on subsequent saves" do
      page = create(:page, raw_html: "<p>safe</p>")
      page.sanitized_html = "<script>alert(1)</script>"
      page.save!
      expect(page.sanitized_html).to include("safe")
      expect(page.sanitized_html).not_to include("<script>")
    end
  end

  describe "#published?" do
    it "is true when both deleted_at and unpublished_at are nil" do
      expect(build(:page, deleted_at: nil, unpublished_at: nil)).to be_published
    end

    it "is false when deleted_at is set" do
      expect(build(:page, deleted_at: Time.current, unpublished_at: nil)).not_to be_published
    end

    it "is false when unpublished_at is set" do
      expect(build(:page, deleted_at: nil, unpublished_at: Time.current)).not_to be_published
    end
  end
end
