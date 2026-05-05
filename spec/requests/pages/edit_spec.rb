# frozen_string_literal: true

require "spec_helper"

describe "Pages happy path", js: true, type: :system do
  let(:seller) { create(:named_seller) }

  before do
    Feature.activate_user(:pages, seller)
    allow_any_instance_of(Pages::CompileTailwindService).to receive(:perform).and_return("/* test stub css */")
    login_as seller
  end

  after do
    Feature.deactivate(:pages)
    Feature.deactivate_user(:pages, seller)
  end

  it "lets a seller create a page from scratch and view it" do
    visit pages_path

    expect(page).to have_text("No pages yet")
    first("a", text: "New page").click

    fill_in "Title", with: "My first page"
    fill_in "HTML", with: "<div class=\"p-4 text-2xl\">Hello world</div>"
    click_on "Create page"

    expect(page).to have_text("Edit page")
    expect(page).to have_field("Title", with: "My first page")

    page_record = seller.pages.alive.last
    expect(page_record.permalink).to be_present
    expect(page_record.sanitized_html).to include("Hello world")
  end

  it "shows the Pages link in the dashboard nav when the seller has the flag" do
    visit dashboard_path
    within("nav[aria-label='Main']") do
      expect(page).to have_link("Pages")
    end
  end

  it "hides the Pages link from the dashboard nav when the seller does not have the flag" do
    Feature.deactivate_user(:pages, seller)
    visit dashboard_path
    within("nav[aria-label='Main']") do
      expect(page).not_to have_link("Pages")
    end
  end

  it "renders a published page inside an iframe sandbox at /p/:permalink" do
    page_record = create(:page, seller: seller, title: "Live page", raw_html: "<a href=\"/checkout?product=abc\" target=\"_top\">Buy now</a>")

    visit "/p/#{page_record.permalink}"

    iframe_sandbox = find("iframe", visible: false)["sandbox"]
    expect(iframe_sandbox).to eq("allow-top-navigation-by-user-activation")
    expect(iframe_sandbox).not_to include("allow-scripts")
    expect(iframe_sandbox).not_to include("allow-same-origin")

    iframe_srcdoc = find("iframe", visible: false)["srcdoc"]
    expect(iframe_srcdoc).to include("Buy now")
    expect(iframe_srcdoc).to include("target=\"_top\"")
    expect(iframe_srcdoc).to include("/checkout?product=abc")
  end
end
