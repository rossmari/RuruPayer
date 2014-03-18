class Rurupayer::Controller < ActionController::Base

  protect_from_forgery :only => []

  def success
    retval = Rurupayer.interface_class.success(params, self)
    redirect_to retval if retval.is_a? String
  end

  def fail
    retval = Rurupayer.interface_class.fail(params, self)
    redirect_to retval if retval.is_a? String
  end

  def callback
    retval = Rurupayer.interface_class.callback(params, self)

    builder = Nokogiri::XML::Builder.new { |xml|
          xml.ServiceResponse('xmlns' => 'http://ruru.service.provider', 'xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance') do
            xml<<retval.to_xml( :skip_types => true, :skip_instruct => true).gsub(/<\/{0,1}hash>\s+/, "")
          end
    }
    puts builder.to_xml

    render :xml => builder.to_xml
  end

end