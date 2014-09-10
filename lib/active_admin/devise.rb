ActiveAdmin::Dependency.devise! ActiveAdmin::Dependency::DEVISE

require 'devise'

module ActiveAdmin
  module Devise

    def self.config
      config = {
        path: ActiveAdmin.application.default_namespace || "/",
        controllers: ActiveAdmin::Devise.controllers,
        path_names: { sign_in: 'login', sign_out: "logout" }
      }

      if ::Devise.respond_to?(:sign_out_via)
        logout_methods = [::Devise.sign_out_via, ActiveAdmin.application.logout_link_method].flatten.uniq
        config.merge!( sign_out_via: logout_methods)
      end

      config
    end

    def self.controllers
      {
        sessions: "active_admin/devise/sessions",
        passwords: "active_admin/devise/passwords",
        unlocks: "active_admin/devise/unlocks",
        registrations: "active_admin/devise/registrations",
        confirmations: "active_admin/devise/confirmations"
      }
    end

    module Controller
      extend ::ActiveSupport::Concern
      included do
        layout 'active_admin_logged_out'
        helper ::ActiveAdmin::ViewHelpers
      end

      # Redirect to the default namespace on logout
      def root_path
        namespace = ActiveAdmin.application.default_namespace.presence
        root_path_method = [namespace, :root_path].compact.join('_')

        url_helpers = Rails.application.routes.url_helpers

        path = if url_helpers.respond_to? root_path_method
                 url_helpers.send root_path_method
               else
                 # Guess a root_path when url_helpers not helpful
                 "/#{namespace}"
               end

        # NOTE: `relative_url_root` is deprecated by rails.
        #       Remove prefix here if it is removed completely.
        prefix = Rails.configuration.action_controller[:relative_url_root] || ''
        prefix + path
      end
    end

    class SessionsController < ::Devise::SessionsController
      include ::ActiveAdmin::Devise::Controller
    end

    class PasswordsController < ::Devise::PasswordsController
      include ::ActiveAdmin::Devise::Controller
    end

    class UnlocksController < ::Devise::UnlocksController
      include ::ActiveAdmin::Devise::Controller
    end

    class RegistrationsController < ::Devise::RegistrationsController
       include ::ActiveAdmin::Devise::Controller
    end

    class ConfirmationsController < ::Devise::ConfirmationsController
      include ::ActiveAdmin::Devise::Controller
      # Remove the first skip_before_filter (:require_no_authentication) if you
      # don't want to enable logged users to access the confirmation page.
      skip_before_filter :require_no_authentication
      skip_before_filter :authenticate_user!

      # PUT /resource/confirmation
      def update
        with_unconfirmed_confirmable do
          if @confirmable.has_no_password?
            @confirmable.attempt_set_password(params[@admin_user_model.name.underscore.to_sym])
            if @confirmable.valid? and @confirmable.password_match?
              do_confirm
            else
              do_show
              @confirmable.errors.clear #so that we wont render :new
            end
          else
            @confirmable.errors.add(:email, :password_already_set)
          end
        end

        if !@confirmable.errors.empty?
          self.resource = @confirmable
          render 'active_admin/devise/confirmations/new'
        end
      end

      # GET /resource/confirmation?confirmation_token=abcdef
      def show
        with_unconfirmed_confirmable do
          if @confirmable.has_no_password?
            do_show
          else
            do_confirm
          end
        end
        if !@confirmable.errors.empty?
          self.resource = @confirmable
          render 'active_admin/devise/confirmations/new'
        end
      end

      protected

      def with_unconfirmed_confirmable
        # Retrieve admin user model from ActiveAdmin config, in case it isn't AdminUser
        admin_current_user_method = ActiveAdmin.application.current_user_method
        @admin_user_model = Object.const_get(admin_current_user_method.to_s.sub("current_","").classify)
        original_token = params[:confirmation_token]
        confirmation_token = ::Devise.token_generator.digest(@admin_user_model, :confirmation_token, original_token)
        @confirmable = @admin_user_model.find_or_initialize_with_error_by(:confirmation_token, confirmation_token)
        if !@confirmable.new_record?
          @confirmable.only_if_unconfirmed {yield}
        end
      end

      def do_show
        @confirmation_token = params[:confirmation_token]
        @requires_password = true
        self.resource = @confirmable
        render 'active_admin/devise/confirmations/show'
      end

      def do_confirm
        @confirmable.confirm!
        set_flash_message :notice, :confirmed
        sign_in_and_redirect(resource_name, @confirmable)
      end
    end

    def self.controllers_for_filters
      [SessionsController, PasswordsController, UnlocksController,
        RegistrationsController, ConfirmationsController
      ]
    end

  end
end
