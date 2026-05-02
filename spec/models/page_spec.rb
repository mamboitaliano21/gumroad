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

    it "rejects content larger than 1MB" do
      page = build(:page, content_html_raw: "x" * (Page::CONTENT_MAX_BYTES + 1))
      expect(page).not_to be_valid
      expect(page.errors[:content_html_raw]).to be_present
    end

    it "accepts content at the size limit" do
      page = build(:page, content_html_raw: "x" * Page::CONTENT_MAX_BYTES)
      expect(page).to be_valid
    end
  end

  describe "slug generation" do
    it "auto-generates an 8-char alphanumeric lowercase slug" do
      page = create(:page)
      expect(page.slug).to match(Page::SLUG_FORMAT)
    end

    it "preserves an explicitly set slug if format is valid" do
      page = create(:page, slug: "abcd1234")
      expect(page.slug).to eq("abcd1234")
    end

    it "retries on collision and eventually succeeds" do
      existing = create(:page).slug
      sequence = [existing, existing, "newslug1"]
      allow(SecureRandom).to receive(:alphanumeric).and_return(*sequence)

      page = create(:page)
      expect(page.slug).to eq("newslug1")
    end

    it "raises after exhausting retry attempts" do
      existing = create(:page).slug
      allow(SecureRandom).to receive(:alphanumeric).and_return(existing)

      expect { Page.generate_slug(max_retries: 3) }.to raise_error(/Failed to generate unique slug/)
    end

    it "rejects slugs that don't match the format" do
      page = build(:page, slug: "ABCDEFGH")
      expect(page).not_to be_valid
      expect(page.errors[:slug]).to be_present
    end

    it "enforces uniqueness" do
      existing = create(:page)
      duplicate = build(:page, slug: existing.slug)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to be_present
    end
  end

  describe "Deletable" do
    it "supports soft-delete" do
      page = create(:page)
      expect(page).to be_alive
      page.mark_deleted!
      expect(page).to be_deleted
    end

    it "alive scope excludes soft-deleted records" do
      alive = create(:page)
      deleted = create(:page).tap(&:mark_deleted!)
      expect(Page.alive).to include(alive)
      expect(Page.alive).not_to include(deleted)
    end
  end

  describe "settings_json" do
    it "defaults to chromeless layout" do
      page = Page.new
      expect(page.settings_json).to eq(Page::DEFAULT_SETTINGS)
    end

    it "supports gumroad layout opt-in" do
      page = create(:page, :gumroad_layout)
      expect(page.settings_json["layout"]).to eq("gumroad")
      expect(page).not_to be_chromeless
    end

    it "fills in default when blank" do
      page = create(:page, settings_json: nil)
      expect(page.reload.settings_json).to eq(Page::DEFAULT_SETTINGS)
    end
  end

  describe "ExternalId" do
    it "exposes a separate external_id distinct from slug" do
      page = create(:page)
      expect(page.external_id).to be_present
      expect(page.external_id).not_to eq(page.slug)
      expect(Page.find_by_external_id(page.external_id)).to eq(page)
    end
  end
end
