# name: Master SSO
# About: Internal for bootstraping master nodes for DiscourseCN
# author: Erick
# version: 0.99

PLUGIN_NAME = "master_sso".freeze

enabled_site_setting :master_sso_enabled

after_initialize do

  module ::MasterSSO
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace MasterSSO
    end
  end

  require_dependency 'application_controller'
  require_dependency 'single_sign_on'
  class MasterSSO::ControlsController < ::ApplicationController
    def sso
      payload ||= request.query_string
      if SiteSetting.master_sso_enabled?
        sso = SingleSignOn.parse(payload, SiteSetting.sso_secret)
        if current_user
          sso.name = current_user.name
          sso.username = current_user.username
          sso.email = current_user.email
          sso.external_id = current_user.id.to_s
          sso.admin = grant_admin?
          sso.moderator = grant_moderator?
          sso.suppress_welcome_message = true
          if request.xhr?
            cookies[:sso_destination_url] = sso.to_url(sso.return_sso_url)
          else
            redirect_to sso.to_url(sso.return_sso_url)
          end
        else
          session[:sso_payload] = request.query_string
          redirect_to path('/login')
        end
      else
        render nothing: true, status: 404
      end
    end

    private
    def grant_admin?
      if SiteSetting.master_sso_admin_admin_required?
        current_user.admin?
      else
        current_user.trust_level >= SiteSetting.master_sso_admin_tl_required
      end
    end

    def grant_moderator?
      current_user.trust_level >= SiteSetting.master_sso_moderator_tl_required
    end
  end

  MasterSSO::Engine.routes.draw do
    get "/sso" => "controls#sso"
  end

  Discourse::Application.routes.append do
    mount ::MasterSSO::Engine, at: '/master_control'
  end
end