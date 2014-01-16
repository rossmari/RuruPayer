Rurupayer::Engine.routes.draw do

  controller :rurupayer do
    get "/:notification_key/notify"   => :notify,  :as => :rurupayer_notification
    get "/success"  => :success,  :as => :rurupayer_on_success
    get "/fail"     => :fail,     :as => :rurupayer_on_fail
    get "/callback" => :callback, :as => :rurupayer_on_callback
  end

end