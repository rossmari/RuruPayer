require "rurupayer/version"

module Rurupayer
  mattr_accessor :interface_class

  def self.interface_class
    @@interface_class || ::Rurupayer::Interface
  end

  class Engine < Rails::Engine
    config.autoload_paths += %W(#{config.root}/lib)

    def self.activate
    end

    config.to_prepare &method(:activate).to_proc
  end


end
