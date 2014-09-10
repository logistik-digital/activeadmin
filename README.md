# Active Admin Confirmable

Fork to add Devise confirmable support to ActiveAdmin. This allows you to create admin users without a password, which they set themselves. After creating an admin record, they will recieve an email with a confirmation URL in which they enter their own password.

## Requirements

Only tested on:

* Devise 3.3.0
* Warden 1.2.3

## Updates

We'll be rebasing this gem 'every so often', when we require new features or security updates to ActiveAdmin. Please feel free to fork and rebase this yourself if required. Instructions for this are at the bottom of the [contrubuting guide.](https://github.com/logistik-digital/activeadmin/blob/add-admin-password-self-selection/CONTRIBUTING.md)

## Instructions
You'll need to add a couple of helper methods to your admin user model, which in most cases will be app/models/admin_user.rb

### Devise

See [the Devise wiki entry](https://github.com/plataformatec/devise/wiki/How-To:-Override-confirmations-so-users-can-pick-their-own-passwords-as-part-of-confirmation-activation) for more thorough detail on what's needed. We are using :admin_users (AdminUser) for the admin user model.

Add confirmable fields to database:

```ruby
class AddAdminUserConfirmable < ActiveRecord::Migration
  def self.up
    add_column :admin_users, :confirmation_token, :string
    add_column :admin_users, :confirmed_at, :datetime
    add_column :admin_users, :confirmation_sent_at, :datetime
    # add_column :admin_users, :unconfirmed_email, :string # Only if using reconfirmable
    add_index :admin_users, :confirmation_token, :unique => true

    AdminUser.update_all({:confirmed_at => DateTime.now, :confirmation_sent_at => DateTime.now})
  end

  def self.down
    remove_column :admin_users, [:confirmed_at, :confirmation_token, :confirmation_sent_at]
  end
end
```

Set reconfirmable in config/intializers/devise.rb:

```ruby
config.reconfirmable = false
```

### Gemfile
Replace activeadmin if it already exists

```ruby
gem 'activeadmin', git: 'https://github.com/logistik-digital/activeadmin.git', branch: 'add-admin-password-self-selection'
```

### Routes
A route will need to be added to allow a PUT to the confirmations controller.
```ruby
  # ActiveAdmin Confirmable Routes
  # Using admin user model set in ActiveAdmin initializers
  admin_current_user_method = ActiveAdmin.application.current_user_method
  admin_user_model = Object.const_get(admin_current_user_method.to_s.sub("current_","").classify)
  devise_scope admin_user_model.name.underscore.to_sym do
    put "/admin/confirmation" => "active_admin/devise/confirmations#update"
  end
```

### Admin user model
In our case admin_user.rb

```ruby
class AdminUser < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  def password_required?
    super if confirmed?
  end

  def password_match?
    self.errors[:password] << "can't be blank" if password.blank?
    self.errors[:password_confirmation] << "can't be blank" if password_confirmation.blank?
    self.errors[:password_confirmation] << "does not match password" if password != password_confirmation
    password == password_confirmation && !password.blank?
  end

  def attempt_set_password(params)
    p = {}
    p[:password] = params[:password]
    p[:password_confirmation] = params[:password_confirmation]
    update_attributes(p)
  end

  def has_no_password?
    self.encrypted_password.blank?
  end

  def only_if_unconfirmed
    pending_any_confirmation {yield}
  end
end
```