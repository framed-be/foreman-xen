require 'fast_gettext'
require 'gettext_i18n_rails'
require 'fog/xenserver'

module ForemanXen
  # Inherit from the Rails module of the parent app (Foreman), not the plugin.
  # Thus, inherits from ::Rails::Engine and not from Rails::Engine
  class Engine < ::Rails::Engine
    engine_name 'foreman_xen'

    initializer 'foreman_xen.register_gettext', :after => :load_config_initializers do |app|
      locale_dir    = File.join(File.expand_path('../..', __dir__), 'locale')
      locale_domain = 'foreman-xen'

      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end

    initializer 'foreman_xen.register_plugin', :before => :finisher_hook do |app|
      Foreman::Plugin.register :foreman_xen do
        requires_foreman '>= 1.13'
        # Register xen compute resource in foreman
        compute_resource ForemanXen::Xenserver
        parameter_filter(ComputeResource, :uuid)
      end
    end

    assets_to_precompile =
      Dir.chdir(root) do
        Dir['app/assets/javascripts/**/*', 'app/assets/stylesheets/**/*'].map do |f|
          f.split(File::SEPARATOR, 4).last
        end
      end

    initializer 'foreman_xen.assets.precompile' do |app|
      app.config.assets.precompile += assets_to_precompile
    end

    initializer 'foreman_xen.configure_assets', group: :assets do
      SETTINGS[:foreman_xen] = { assets: { precompile: assets_to_precompile } }
    end

    config.to_prepare do
      begin
        # extend fog xen server and image models.
        require 'fog/compute/xen_server/models/server'
        require File.expand_path('../../app/models/concerns/fog_extensions/xenserver/server', __dir__)
        require File.expand_path('../../app/models/concerns/foreman_xen/host_helper_extensions', __dir__)

        Fog::Compute::XenServer::Server.send(:include, ::FogExtensions::Xenserver::Server)
        ::HostsHelper.send(:include, ForemanXen::HostHelperExtensions)
      rescue => e
        Rails.logger.warn "Foreman-Xen: skipping engine hook (#{e})"
      end
    end
  end
end
