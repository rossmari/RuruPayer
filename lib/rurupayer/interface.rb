require 'cgi'
require 'net/http'
require 'net/https'
require 'open-uri'
require 'rexml/document'
require 'digest/sha1'

class Rurupayer::Interface
  include ActionDispatch::Routing::UrlFor
  include Rails.application.routes.url_helpers

  cattr_accessor :config

  @@default_options = {
      :language => "ru",
      :success_path => "#{@options[:root_url]}/rurupayer/success",
      :notify_path => "#{@options[:root_url]}/rurupayer/notify",
      :fail_path => "#{@options[:root_url]}/rurupayer/notify"
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
    @cache   = {}
  end

  def notify(params, controller)
    #make params map
    notify_implementation({},  controller)
    #ansver xml
  end

  def self.success(params, controller)
    #make params map
    success_implementation({}, controller)
    #ansver xml
  end

  def self.fail(params, controller)
    #make params map
    fail_implementation({}, controller)
  end

  # создание урла для оплаты
  def init_payment_url(invoice_id, amount, custom_options={})
    url_options = init_payment_options(invoice_id, amount, custom_options)
    "#{base_url}?" + url_options.to_param
  end

  def init_payment_options(invoice_id, amount, description, custom_options = {})
    options = {
        :partner_id       => @options[:partner_id],
        :service_id       => @options[:service_id],

        :amount      => amount.to_s,
        :invoice_id  => invoice_id, # or order id - идентификтор заказа

        :success_url       => on_success_url,
        :failure_url       => on_fail_url,

        #:description => description[0, 100],
        :signature   => init_payment_signature(invoice_id, amount, custom_options)
        #:currency    => currency,
        #:email       => email,
        #:language    => language

    }.merge(Hash[custom_options.sort.map{|x| ["shp#{x[0]}", x[1]]}])

    #map_params(options, @@params_map)

    options.to_param
  end

  def parse_response_params(params)
    parsed_params = map_params(params, @@notification_params_map)
    parsed_params[:custom_options] = Hash[args.select do |k,v| o.starts_with?('shp') end.sort.map do|k, v| [k[3, k.size], v] end]
    if response_signature(parsed_params)!=parsed_params[:signature].downcase
      raise "Invalid signature"
    end
  end

  def init_payment_signature(invoice_id, amount, custom_options={})
    Base64.encode64(init_payment_signature_string(invoice_id, amount, custom_options))
  end


  def init_payment_signature_string(invoice_id, amount, custom_options={})
    custom_params_string = custom_options.sort.map{|x| "#{x[0]}=#{x[1]}"}.join('')
    params_string =  "#{invoice_id}#{amount}" + "#{@options[:partner_id]}#{@options[:service_id]}#{@options[:success_url]}#{@options[:failure_url]}"

    encoded_partner_key = Base64::decode64(@options[:partner_key])
    Digest::SHA1.hexdigest(encoded_partner_key + params_string + custom_params_string)
  end

  # returns http://test.robokassa.ru or https://merchant.roboxchange.com in order to current mode
  def base_url
    test_mode? ? 'http://widget.test.ru' : 'https://widget.ru/partner'
  end

  def map_params(params, map) #:nodoc:
    self.class.map_params params, map
  end

  #def payment_methods # :nodoc:
  #  return @cache[:payment_methods] if @cache[:payment_methods]
  #  xml = get_remote_xml(payment_methods_url)
  #  if xml.elements['PaymentMethodsList/Result/Code'].text != '0'
  #    raise (a=xml.elements['PaymentMethodsList/Result/Description']) ? a.text : "Unknown error"
  #  end
  #
  #  @cache[:payment_methods] ||= Hash[xml.elements.each('PaymentMethodsList/Methods/Method'){}.map do|g|
  #    [g.attributes['Code'], g.attributes['Description']]
  #  end]
  #end
  #
  #def rates_long(amount, currency='')
  #  cache_key = "rates_long_#{currency}_#{amount}"
  #  return @cache[cache_key] if @cache[cache_key]
  #  xml = get_remote_xml(rates_url(amount, currency))
  #  if xml.elements['RatesList/Result/Code'].text != '0'
  #    raise (a=xml.elements['RatesList/Result/Description']) ? a.text : "Unknown error"
  #  end
  #
  #  @cache[cache_key] = Hash[xml.elements.each('RatesList/Groups/Group'){}.map do|g|
  #    code = g.attributes['Code']
  #    description = g.attributes['Description']
  #    [
  #        code,
  #        {
  #            :code        => code,
  #            :description => description,
  #            :currencies  => Hash[g.elements.each('Items/Currency'){}.map do|c|
  #              label = c.attributes['Label']
  #              name  = c.attributes['Name']
  #              [label, {
  #                  :currency             => label,
  #                  :currency_description => name,
  #                  :group                => code,
  #                  :group_description    => description,
  #                  :amount => BigDecimal.new(c.elements['Rate'].attributes['IncSum'])
  #              }]
  #            end]
  #        }
  #    ]
  #  end]
  #end

  #def rates(amount, currency='')
  #  cache_key = "rates_#{currency}_#{amount}"
  #  @cache[cache_key] ||= Hash[rates_long(amount, currency).map do |key, value|
  #    [key, {
  #        :description => value[:description],
  #        :currencies => Hash[(value[:currencies] || []).map do |k, v|
  #          [k, v]
  #        end]
  #    }]
  #  end]
  #end

  #def rates_linear(amount, currency='')
  #  cache_key = "rates_linear#{currency}_#{amount}"
  #  @cache[cache_key] ||= begin
  #    retval = rates(amount, currency).map do |group|
  #      group_name, group = group
  #      group[:currencies].map do |currency|
  #        currency_name, currency = currency
  #        {
  #            :name       => currency_name,
  #            :desc       => currency[:currency_description],
  #            :group_name => group[:name],
  #            :group_desc => group[:description],
  #            :amount     => currency[:amount]
  #        }
  #      end
  #    end
  #    Hash[retval.flatten.map { |v| [v[:name], v] }]
  #  end
  #end

  #def currencies_long
  #  return @cache[:currencies_long] if @cache[:currencies_long]
  #  xml = get_remote_xml(currencies_url)
  #  if xml.elements['CurrenciesList/Result/Code'].text != '0'
  #    raise (a=xml.elements['CurrenciesList/Result/Description']) ? a.text : "Unknown error"
  #  end
  #  @cache[:currencies_long] = Hash[xml.elements.each('CurrenciesList/Groups/Group'){}.map do|g|
  #    code = g.attributes['Code']
  #    description = g.attributes['Description']
  #    [
  #        code,
  #        {
  #            :code        => code,
  #            :description => description,
  #            :currencies  => Hash[g.elements.each('Items/Currency'){}.map do|c|
  #              label = c.attributes['Label']
  #              name  = c.attributes['Name']
  #              [label, {
  #                  :currency             => label,
  #                  :currency_description => name,
  #                  :group                => code,
  #                  :group_description    => description
  #              }]
  #            end]
  #        }
  #    ]
  #  end]
  #end
  #
  #def currencies
  #  @cache[:currencies] ||= Hash[currencies_long.map do |key, value|
  #    [key, {
  #        :description => value[:description],
  #        :currencies => value[:currencies]
  #    }]
  #  end]
  #end

  # for testing
  # === Example
  # i.default_url_options = { :host => '127.0.0.1', :port => 3000 }
  ## i.notification_url # => 'http://127.0.0.1:3000/robokassa/asfadsf/notify'
  #def notification_url
  #  rurupayer_notification_url :notification_key => @options[:notification_key]
  #end

  ## for testing
  #def on_success_url
  #  rurupayer_on_success_url
  #end
  #
  ## for testing
  #def on_fail_url
  #  rurupayer_on_fail_url
  #end



  #def rates_url(amount, currency)
  #  "#{xml_services_base_url}/GetRates?#{query_string(rates_options(amount, currency))}"
  #end
  #
  #def rates_options(amount, currency)
  #  map_params(subhash(@options.merge(:amount=>amount, :currency=>currency), %w{login language amount currency}), @@service_params_map)
  #end
  #
  #def payment_methods_url
  #  @cache[:get_currencies_url] ||= "#{xml_services_base_url}/GetPaymentMethods?#{query_string(payment_methods_options)}"
  #end
  #
  #def payment_methods_options
  #  map_params(subhash(@options, %w{login language}), @@service_params_map)
  #end
  #
  #def currencies_url
  #  @cache[:get_currencies_url] ||= "#{xml_services_base_url}/GetCurrencies?#{query_string(currencies_options)}"
  #end

  #def currencies_options
  #  map_params(subhash(@options, %w{login language}), @@service_params_map)
  #end

  # make hash of options for init_payment_url


  # calculates signature to check params from Robokassa
  #def response_signature(parsed_params)
  #  md5 response_signature_string(parsed_params)
  #end

  ## build signature string
  #def response_signature_string(parsed_params)
  #  custom_options_fmt = custom_options.sort.map{|x|"shp#{x[0]}=x[1]]"}.join(":")
  #  "#{parsed_params[:amount]}:#{parsed_params[:invoice_id]}:#{@options[:password2]}#{unless custom_options_fmt.blank? then ":" + custom_options_fmt else "" end}"
  #end




  # returns base url for API access
  #def xml_services_base_url
  #  "#{base_url}/WebService/Service.asmx"
  #end

  #@@notification_params_map = {
  #    'OutSum'         => :amount,
  #    'InvId'          => :invoice_id,
  #    'SignatureValue' => :signature,
  #    'Culture'        => :language
  #}
  #
  #@@params_map = {
  #    'MrchLogin'      => :login,
  #    'OutSum'         => :amount,
  #    'InvId'          => :invoice_id,
  #    'Desc'           => :description,
  #    'Email'          => :email,
  #    'IncCurrLabel'   => :currency,
  #    'Culture'        => :language,
  #    'SignatureValue' => :signature
  #}.invert
  #
  #@@service_params_map = {
  #    'MerchantLogin'  => :login,
  #    'Language'       => :language,
  #    'IncCurrLabel'   => :currency,
  #    'OutSum'         => :amount
  #}.invert

  #def md5(str) #:nodoc:
  #  Digest::MD5.hexdigest(str).downcase
  #end

  #def subhash(hash, keys) #:nodoc:
  #  Hash[keys.map do |key|
  #    [key.to_sym, hash[key.to_sym]]
  #  end]
  #end

  #  # Maps gem parameter names, to robokassa names
  #  def self.map_params(params, map)
  #    Hash[params.map do|key, value| [(map[key] || map[key.to_sym] || key), value] end]
  #  end
  #



  #
  #  def query_string(params) #:nodoc:
  #    params.map do |name, value|
  #      "#{CGI::escape(name.to_s)}=#{CGI::escape(value.to_s)}"
  #    end.join("&")
  #  end
  #
  #  # make request and parse XML from specified url
  #  def get_remote_xml(url)
  ##   xml_data = Net::HTTP.get_response(URI.parse(url)).body
  #    begin
  #      xml_data = URI.parse(url).read
  #      doc = REXML::Document.new(xml_data)
  #    rescue REXML::ParseException => e
  #      sleep 1
  #      get_remote_xml(url)
  #    end
  #  end

  class << self
    # This method creates new instance of Interface for specified key (for multi-account support)
    # it calls then Robokassa call ResultURL callback
    def create_by_notification_key(key)
      self.new get_options_by_notification_key(key)
    end

    %w{success fail notify}.map{|m| m + '_implementation'} + ['get_options_by_notification_key'].each do |m|
      define_method m.to_sym do |*args|
        raise NoMethodError, "RuruPay::Interface.#{m} should be defined by app developer"
      end
    end
  end
end
