# LetsEncrypt [![Gem Version](https://badge.fury.io/rb/rails-letsencrypt.svg)](https://badge.fury.io/rb/rails-letsencrypt) [![Build Status](https://travis-ci.org/elct9620/rails-letsencrypt.svg?branch=master)](https://travis-ci.org/elct9620/rails-letsencrypt) [![Coverage Status](https://coveralls.io/repos/github/elct9620/rails-letsencrypt/badge.svg?branch=master)](https://coveralls.io/github/elct9620/rails-letsencrypt?branch=master) [![Code Climate](https://codeclimate.com/github/elct9620/rails-letsencrypt/badges/gpa.svg)](https://codeclimate.com/github/elct9620/rails-letsencrypt)

Provide manageable Let's Encrypt Certificate for Rails.

## Installation

Puts this in your Gemfile:

```ruby
gem 'rails-letsencrypt'
```

Run install migrations

```bash
rails generate lets_encrypt:install
rake db:migrate
```

Setup private key for Let's Encrypt API

```bash
rails generate lets_encrypt:register
```


Add `acme-challenge` mounts in `config/routes.rb`
```ruby
mount LetsEncrypt::Engine => '/.well-known'
```

### Configuration

Add a file to `config/initializers/letsencrypt.rb` and put below config you need.

```ruby
LetsEncrypt.config do |config|
  # Using Let's Encrypt staging server or not
  # Default only `Rails.env.production? == true` will use Let's Encrypt production server.
  config.use_staging = true

  # Set the private key path
  # Default is locate at config/letsencrypt.key
  config.private_key_path = Rails.root.join('config', 'letsencrypt.key')

  # Use environment variable to set private key
  # If enable, the API Client will use `LETSENCRYPT_PRIVATE_KEY` as private key
  # Default is false
  config.use_env_key = false

  # Should sync certificate into redis
  # When using ngx_mruby to dynamic load certificate, this will be helpful
  # Default is false
  config.save_to_redis = false

  # The redis server url
  # Default is nil
  config.redis_url = 'redis://localhost:6379/1'
end
```

## Usage

The SSL certificate setup depends on the web server, this gem can work with `ngx_mruby` or `kong`.

### Certificate Model

#### Create

Add a new domain into the database.

```ruby
cert = LetsEncrypt::Certificate.create(domain: 'example.com')
cert.get # alias  `verify && issue`
```

#### Verify

Makes a request to Let's Encrypt and verify domain

```ruby
cert = LetsEncrypt::Certificate.find_by(domain: 'example.com')
cert.verify
```

#### Issue

Ask Let's Encrypt to issue a new certificate.

```ruby
cert = LetsEncrypt::Certificate.find_by(domain: 'example.com')
cert.issue
```

#### Renew

```ruby
cert = LetsEncrypt::Certificate.find_by(domain: 'example.com')
cert.renew
```

#### Status

Check a certificate is verified and issued.

```ruby
cert = LetsEncrypt::Certificate.find_by(domain: 'example.com')
cert.active? # => true
```

Check a certificate is expired.

```ruby
cert = LetsEncrypt::Certificate.find_by(domain: 'example.com')
cert.expired? # => false
```

### Tasks

To renew a certificate, you can run `renew` task to renew coming expires certificates.

```bash
rake letsencrypt:renew
```

### Jobs

If you are using Sidekiq or others, you can enqueue renew task daily.

```
LetsEncrypt::RenewCertificatesJob.perform_later
```

### ngx_mruby

The setup is following this [Article](http://hb.matsumoto-r.jp/entry/2017/03/23/173236)

Add `config/initializers/letsencrypt.rb` to add config to sync certificate.

```ruby
LetsEncrypt.config do |config|
  config.redis_url = 'redis://localhost:6379/1'
  config.save_to_redis = true
end
```

Connect `Redis` when Nginx worker start
```
http {
  # ...
  mruby_init_worker_code '
    userdata = Userdata.new
    userdata.redis = Redis.new "127.0.0.1", 6379
    # If your redis database is not 0, please select a correct one
    userdata.redis.select 1
  ';
}
```

Setup SSL using mruby
```
server {
  listen 443 ssl;
  server_name _;

  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers HIGH:!aNULL:!MD5;
  ssl_certificate certs/dummy.crt;
  ssl_certificate_key certs/dummy.key;

  mruby_ssl_handshake_handler_code '
    ssl = Nginx::SSL.new
    domain = ssl.servername

    redis = Userdata.new.redis
    unless redis["#{domain}.crt"].nil? and redis["#{domain}.key"].nil?
      ssl.certificate_data = redis["#{domain}.crt"]
      ssl.certificate_key_data = redis["#{domain}.key"]
    end
  ';
}
```

### Kong

Coming soon.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
