module ForemanM2
  # class BareMetalM2 < ComputeResource
  # end

  class Engine < ::Rails::Engine
    engine_name 'foreman_m2'

    config.autoload_paths += Dir["#{config.root}/app/controllers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/helpers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/models/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/models/foreman_m2"]
    config.autoload_paths += Dir["#{config.root}/app/overrides"]

    # Add any db migrations
    initializer 'foreman_m2.load_app_instance_data' do |app|
      ForemanM2::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer 'foreman_m2.register_plugin',
                :before => :finisher_hook do |_app|
      Foreman::Plugin.register :foreman_m2 do
        requires_foreman '>= 1.16'

        compute_resource M2
        parameter_filter ComputeResource, :url, :user, :password

        # Add permissions
        security_block :foreman_m2 do
          permission :view_foreman_m2, :'foreman_m2/hosts' => [:new_action]
        end

        # Add a new role called 'ForemanM2' if it doesn't exist
        role 'ForemanM2', [:view_foreman_m2]

        provision_method 'hybrid', 'Network & Image Based'
      end
    end

    # Include concerns in this config.to_prepare block
    config.to_prepare do
      begin
        ComputeResource.send(:prepend, ForemanM2::ComputeResourceExtensions)
        Host::Managed.send(:prepend, ForemanM2::HostExtensions)
        Nic::Managed.send(:prepend, ForemanM2::NicOrchestrationExtensions)
        Nic::Managed.send(:prepend, ForemanM2::NicExtensions)
        Host::Managed.send(:prepend, ForemanM2::HostOrchestrationExtensions)
        HostsHelper.send(:include, ForemanM2::HostsHelperExtensions)
        ImagesHelper.send(:prepend, ForemanM2::ImagesHelperExtensions)
      rescue StandardError => e
        Rails.logger.warn "ForemanM2: skipping engine hook (#{e})"
      end
    end

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanM2::Engine.load_seed
      end
    end

    initializer 'foreman_m2.register_gettext',
                after: :load_config_initializers do |_app|
      locale_dir = File.join(File.expand_path('../..', __dir__), 'locale')
      locale_domain = 'foreman_m2'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end
  end
end
