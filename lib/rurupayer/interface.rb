require 'cgi'
require 'net/http'
require 'net/https'
require 'open-uri'
require 'rexml/document'
require 'digest/hmac'
require 'base64'

class Rurupayer::Interface
  include ActionDispatch::Routing::UrlFor
  include Rails.application.routes.url_helpers

  @@default_options = {
      language: 'ru',
  }
  @cache = {}

  def test_mode?
    @options[:test_mode] || false
  end

  def owner
    @options[:owner]
  end

  def initialize(options)
    @options = @@default_options.merge(options.symbolize_keys)
    @options[:success_path] = "#{@options[:root_url]}/rurupayer/success"
    @options[:fail_path] = "#{@options[:root_url]}/rurupayer/fail"
    @cache   = {}
  end

  def self.success(params, controller)
    #make params map
    success_implementation(params[:invoice_id], controller)
    #ansver xml
  end

  def self.fail(params, controller)
    #make params map
    fail_implementation(params[:invoice_id] , controller)
  end

  def self.callback(params, controller)
    params[:action] = /\?action=(\S+?)&/.match(controller.request.fullpath)[1]

    if check_response_signature(params)
      success_callback_implementation(params)
    else
      fail_callback_implementation(params)
    end
  end

  def construct_absolute_path(path, arg = {})
    "#{path}?#{query_string(arg)}"
  end

  # создание урла для оплаты
  def init_payment_url(invoice_id, amount, custom_options={})
    url_options = init_payment_options(invoice_id, amount, custom_options)
    "#{base_url}?" + url_options
  end

  def init_payment_options(invoice_id, amount, custom_options = {})
    options = {

        # or order id - идентификтор заказа
        order_id:     invoice_id,
        amount:       amount.to_s,

        partner_id:   @options[:partner_id],
        service_id:   @options[:service_id],

        success_url:  construct_absolute_path(@options[:success_path], invoice_id: invoice_id),
        failure_url:  construct_absolute_path(@options[:fail_path], invoice_id: invoice_id)
    }

    options[:signature] = init_payment_signature(options)

    query_string(options)
  end

  def self.check_response_signature(params)
    #remove controller name and signature from params set
    # prepare params
    params.delete(:controller)
    signature = params.delete(:signature)
    signature == create_signature(params)
  end

  # static for Signature
  def self.create_signature(params)
    params_string = params.map{|p| p[1]}.join()
    puts "S #{params_string} E"
    encoded_partner_key = Base64::decode64(get_options_by_notification_key('')[:source_key])
    sha_digest = OpenSSL::HMAC.digest('SHA1',encoded_partner_key, params_string)
    Base64.encode64(sha_digest).gsub("\n",'')
  end


  def init_payment_signature(options)
    Base64.encode64(init_payment_signature_string(options)).gsub("\n",'')
  end

  def init_payment_signature_string(options)
    params_string = params_string(options)
    encoded_partner_key = Base64::decode64(@options[:source_key])
    OpenSSL::HMAC.digest('SHA1',encoded_partner_key, params_string)
  end

  def base_url
    test_mode? ? 'https://wdemo.ruru.ru/partner' : 'https://widget.ruru.ru/partner'
  end

  def map_params(params, map) #:nodoc:
    self.class.map_params params, map
  end

  def query_string(params) #:nodoc:
    params.map do |name, value|
      "#{CGI::escape(name.to_s)}=#{CGI::escape(value.to_s)}"
    end.join("&")
  end

  def params_string(options)
    options.map{|x| x[1]}.join()
  end

  def self.generate_payment_response(params, error_code, error_desc)
    response_body =
        {
            Amount:     params[:amount],
            Date:       params[:date],
            ExternalId: params[:externalId],
            Info:       '',
            Id:         params[:id]
        }

    response = {
        ErrorCode:          error_code,
        ErrorDescription:   error_desc,
        Signature:          '',
    }
    response[:Signature] = Rurupayer.interface_class.create_signature(response.merge(response_body))
    response[:WillCallback] = 'false'
    response[:ResponseBody] = response_body
    response
  end

  def self.generate_cancel_init_response(params, error_code, error_desc)
    response_body =
        {
            Date:       params[:date],
            ExternalId: params[:externalId],
            Id:         params[:id]
        }

    response = {
        ErrorCode:          error_code,
        ErrorDescription:   error_desc,
        Signature:          '',
    }
    response[:Signature] = Rurupayer.interface_class.create_signature(response.merge(response_body))
    response[:ResponseBody] = response_body
    response
  end

  class << self
    # This method creates new instance of Interface for specified key (for multi-account support)
    # it calls then Rurupayer call ResultURL callback
    def create_by_notification_key(key)
      self.new get_options_by_notification_key(key)
    end

    %w{success fail success_callback fail_callback}.map{|m| m + '_implementation'} + ['get_options_by_notification_key'].each do |m|
      define_method m.to_sym do |*args|
        raise NoMethodError, "RuruPay::Interface.#{m} should be defined by app developer"
      end
    end
  end
end
