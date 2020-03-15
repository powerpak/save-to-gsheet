require "require_all"
require "sinatra/base"
require "sinatra/json"
require "google_drive"
require "yaml"
require "net/http"

require_all "lib/"

module SaveToGSheet
  
  RECAPTCHA_URI = "https://www.google.com/recaptcha/api/siteverify"
  RECAPTCHA_THRESHOLD = 0.5
  RECAPTCHA_ACTION = "submit"
  
  class << self
    attr_accessor :config
  end
  
  def self.new(config_path)
    @config = YAML::load(File.open("config.dist.yaml"))
    if File.file?(config_path)
      @config.deep_merge!(YAML::load(File.open(config_path))) 
    end
    
    App
  end
  
  class EndpointNotFound < Sinatra::NotFound; end
  
  class ConfigurationError < RuntimeError
    def initialize(msg="There was an error in your config.yaml."); super; end
  end
  
  class IncompleteSubmission < RuntimeError
    def initialize(msg="Incomplete data was submitted for this endpoint."); super; end
  end
  
  class RecaptchaError < RuntimeError
    def initialize(msg="This request did not contain a valid reCAPTCHA token."); super; end
  end
  
  class GoogleDriveError < RuntimeError
    def initialize(msg="The Google Spreadsheets API returned an error."); super; end
  end

  class App < Sinatra::Base
    
    configure :development do
      set :show_exceptions, :after_handler
    end
    
    register Sinatra::CrossOrigin
    set :allow_methods, [:post]
    set :allow_credentials, false
    
    def config; SaveToGSheet.config; end
    
    def default_google_secret; config["default_google_secret"]; end
    def recaptcha_uri; config["recaptcha_uri"] || RECAPTCHA_URI; end
    
    def get_worksheet(endpoint, end_spec)
      secret = end_spec["google_secret"] || default_google_secret
      @sessions ||= {}
      @spreadsheets ||= {}
      @worksheets ||= {}
      @sessions[secret] ||= GoogleDrive::Session.from_service_account_key(secret)
      @spreadsheets[endpoint] ||= @sessions[secret].spreadsheet_by_key(end_spec["spreadsheet_key"])
      @worksheets[endpoint] ||= @spreadsheets[endpoint].worksheets[end_spec["worksheet"]]
    end
    
    def recaptcha_verify(end_spec, remote_ip, response)
      res = Net::HTTP.post_form(
        URI.parse(recaptcha_uri),
        {
          "secret" => end_spec["recaptcha"]["secret"],
          "remoteip"   => remote_ip,
          "response"   => response
        }
      )
      JSON.parse(res.body)
    end
    
    post "/:_endpoint" do
      endpoint = params[:_endpoint]
      end_spec = config["endpoints"][endpoint]
      raise EndpointNotFound unless end_spec
      recaptcha = {}
      recaptcha_fail = false
      recaptcha_fail_silently = end_spec["recaptcha"] && end_spec["recaptcha"]["fail_silently"]
      
      if end_spec["allowed_origins"]
        cross_origin :allow_origin => end_spec["allowed_origins"]
      end
      
      if end_spec["recaptcha"]
        recaptcha_threshold = end_spec["recaptcha"]["threshold"] || RECAPTCHA_THRESHOLD
        recaptcha_action = end_spec["recaptcha"]["action"] || RECAPTCHA_ACTION
        begin
          raise RecaptchaError unless params[:_recaptcha_response]
          recaptcha = recaptcha_verify(end_spec, request.ip, params[:_recaptcha_response])
          raise RecaptchaError unless recaptcha["success"]
          raise RecaptchaError unless recaptcha["score"] >= recaptcha_threshold
          raise RecaptchaError unless recaptcha["action"] == recaptcha_action
        rescue RecaptchaError
          raise unless recaptcha_fail_silently 
          recaptcha_fail = true
        end
      end
      
      new_row = []
      end_spec["fields"].each do |field|
        raise IncompleteSubmission unless params[field]
        new_row << params[field]
      end
      if end_spec["recaptcha"] && end_spec["recaptcha"]["save_score"] && recaptcha["score"]
        new_row << recaptcha["score"]
      end
      
      begin
        if recaptcha_fail
          halt json({success: false}) unless recaptcha_fail_silently
        else
          sheet = get_worksheet(endpoint, end_spec)
          sheet.insert_rows(sheet.num_rows + 1, [new_row])
          sheet.save
        end
        json({success: true})
      rescue
        raise GoogleDriveError
      end
    end
    
    get "/example" do
      raise EndpointNotFound if settings.production?
      send_file "./EXAMPLE-frontend.html"
    end
    
    not_found do
      err = env['sinatra.error']
      if request.request_method == "POST"
        msg = "You tried to POST data to an endpoint that doesn't exist."
      else
        example = settings.production? ? "" : " except for the example frontend at /example" 
        msg = "This application only responds to HTTP POST requests#{example}."
      end
      status 404
      json({error: true, type: err.class.to_s, message: msg})
    end
    
    error RuntimeError do
      err = env['sinatra.error']
      status 500
      json({error: true, type: err.class.to_s, message: err.message})
    end
    
  end
  
end