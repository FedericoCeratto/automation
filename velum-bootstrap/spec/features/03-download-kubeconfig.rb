require "spec_helper"
require 'uri'
require 'yaml'
require 'net/http'

feature "Download Kubeconfig" do
  before(:each) do
    unless self.inspect.include? "User registers"
      login
    end
  end

  # Using append after in place of after, as recommended by
  # https://github.com/mattheworiordan/capybara-screenshot#common-problems
  append_after(:each) do
    Capybara.reset_sessions!
  end

  scenario "User downloads the kubeconfig file" do
    visit "/"

    expect(page).to have_text("You currently have no nodes to be accepted for bootstrapping", wait: 240)

    puts ">>> User clicks to download kubeconfig"
    expect(page).to have_text("kubectl config")
    with_screenshot(name: :download_kubeconfig) do
      click_on "kubectl config"
    end
    puts "<<< User clicks to download kubeconfig"

    puts ">>> User logs in to Dex"
    expect(page).to have_text("Log in to Your Account")
    with_screenshot(name: :oidc_login) do
      fill_in "login", with: "test@test.com"
      fill_in "password", with: "password"
      click_button "Login"
    end
    puts "<<< User logs in to Dex"

    if page.html =~ /apiVersion/
      # CaaSP KVM Only
      expect(page).to have_text("apiVersion")
      File.write("kubeconfig", Nokogiri::HTML(page.body).xpath("//pre").text)
    else
      puts ">>> User is redirected back to velum"
      expect(page).to have_text("You will see a download dialog")
      puts "<<< User is redirected back to velum"

      # OpenStack/Baremetal/etc
      puts ">>> User is prompted to download the kubeconfig"
      download_uri = URI(page.html.match(/window\.location\.href = "(.*?)"/).captures[0])

      http = Net::HTTP.new(download_uri.host, download_uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(download_uri.request_uri)
      response = http.request(request)

      File.write("kubeconfig", response.body)
      puts "<<< User is prompted to download the kubeconfig"
    end
  end
end
