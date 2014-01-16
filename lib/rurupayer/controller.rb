class Rurupayer::Controller < ActionController::Base

  protect_from_forgery :only => []

  def notify
    interface = Rurupayer.interface_class.create_by_notification_key params[:notification_key]
    params.delete :notification_key
    render :text => interface.notify(params, self)
  end

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
    redirect_to retval if retval.is_a? String
  end

end