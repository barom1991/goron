require 'bundler'
Bundler.require

require 'json'
require 'net/http'
require 'uri'

USERS = %w(
  katsuaki.tanaka
).freeze

COMMANDS = %w(
  hello
  bye
  help
).freeze

#### sinatra ####

get '/' do
  'Hello world!!'
end

post '/' do
  content_type "application/json"

  puts params[:token]
  puts ENV["SLACK_TOKEN"]

  raise 'token がおかしいです' unless ENV["SLACK_TOKEN"] == params[:token]
  raise '許可されていないユーザです' unless USERS.include?(params[:user_name])

  command, *args = params[:text].split(" ")

  return send_message('わからないゴロ〜') unless COMMANDS.include?(command)
  return handle_usage if command == 'help'

  Kernel.fork do
    current_time = now
    driver = start_driver
    switch_to_input_screen(driver)

    if command == 'hello'
      # 出勤
      input_work_field(driver, path: '//td[@id="grdXyw1100G-rc-0-6"]', time: current_time)
      submit(driver)
      send_message("おはようゴロ〜 #{current_time}", url: params[:response_url])
    elsif command == 'bye'
      # 退勤
      input_work_field(driver, path: '//td[@id="grdXyw1100G-rc-0-9"]', time: current_time)
      submit(driver)
      send_message("お疲れゴロ〜 #{current_time}", url: params[:response_url])
    end
  end

  send_message('...ゴロ〜', url: params[:response_url])
end

error 500 do
  e = env['sinatra.error']
  send_message(e.message)
end

#################


# 現在時刻
def now
  Time.now.strftime('%H:%M')	
end

# ドライバの起動
def start_driver
	chrome_capabilities = Selenium::WebDriver::Remote::Capabilities.chrome()
  Selenium::WebDriver.for(
    :remote,
    :url => 'http://hub:4444/wd/hub',
    :desired_capabilities => chrome_capabilities
  )
end

# 勤務入力画面に遷移
def switch_to_input_screen(driver)
  # 移動サイト指定
  driver.navigate.to ENV["LOGIN_URL"]
  
  # 会社コード入力
  driver.find_element(:name, 'DataSource').send_keys(ENV["COMPANY_CODE"])
  # 個人コード入力
  driver.find_element(:name, 'LoginID').send_keys(ENV["EMPLOYEE_CODE"])
  # パスワード入力
  driver.find_element(:name, 'PassWord').send_keys(ENV["PASSWORD"])
  # ログイン処理
  driver.find_element(:xpath, '//td[@class="loginBtn"]').click
  
  # frameの指定
  driver.switch_to.frame driver.find_element(id: 'FRAME1')
  # 勤務データ入力遷移
  driver.find_element(:xpath, '//a[@title="勤務データ入力"]').click
end

# 出勤/退勤時間の入力
def input_work_field(driver, path:, time:)
  # 一旦main documentに戻る
  driver.switch_to.default_content
  # frameの指定
  driver.switch_to.frame driver.find_element(name: 'FRAME2')

  # 出勤/退勤時間の入力
  work_field = driver.find_element(:xpath, path)
  driver.action.send_keys(work_field, time).perform
end

# 登録処理
def submit(driver)
  # 登録処理
  driver.find_element(:xpath, '//input[@name="regbutton"]').click
  # ドライバの終了
  driver.quit
end

# メッセージ処理
def send_message(messages, url: nil)
  body = {
    "response_type": "in_channel",
    "text": Array(messages).join("\n")
  }

  puts body

  if url
    url = URI.parse(url)
    req = Net::HTTP::Post.new(url, "Content-Type" => "application/json")
    req.body = body.to_json
    https = Net::HTTP.new(url.hostname, url.port)
    https.use_ssl = true
    res = https.request(req)

    puts res.code
    puts res.body
  else
    body.to_json
  end
end

# 日付入力
def handle_date(date_time)
  # 日付の整形
  day = DateTime.parse(date_time).strftime('%Y/%m/%d')

  # 処理期間の入力
  driver.find_element(:xpath, '//input[@name="StartYMD"]').send_keys(day)
  driver.find_element(:xpath, '//input[@name="EndYMD"]').send_keys(day)

  # 検索
  driver.find_element(:xpath, '//input[@name="srchbutton"]').click
end

# 使用方法
def handle_usage
  send_message(<<~EOS)
    使い方ゴロ〜:

    /goron hello - 出勤時間の入力
    /goron bye   - 退勤時間の入力
  EOS
end




