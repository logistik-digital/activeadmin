# Active Admin Confirmable

Fork to add Devise confirmable support to ActiveAdmin. This allows you to create admin users without a password, which they set themselves. After creating an admin record, they will recieve an email with a confirmation URL in which they enter their own password.

## Instructions
You'll need to add a couple of helper methods to your admin user model, which in most cases will be app/models/admin_user.rb

### Gemfile
(Replace activeadmin if it already exists)

```ruby
gem 'activeadmin', git: 'https://github.com/logistik-digital/activeadmin.git', branch: 'add-admin-password-self-selection'
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