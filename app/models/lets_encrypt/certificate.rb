# frozen_string_literal: true

module LetsEncrypt
  # == Schema Information
  #
  # Table name: letsencrypt_certificates
  #
  #  id                  :integer          not null, primary key
  #  domain              :string(255)
  #  certificate         :text(65535)
  #  intermediaries      :text(65535)
  #  key                 :text(65535)
  #  expires_at          :datetime
  #  renew_after         :datetime
  #  verification_path   :string(255)
  #  verification_string :string(255)
  #  created_at          :datetime         not null
  #  updated_at          :datetime         not null
  #
  # Indexes
  #
  #  index_letsencrypt_certificates_on_domain       (domain)
  #  index_letsencrypt_certificates_on_renew_after  (renew_after)
  #
  class Certificate
    include Mongoid::Document
    include Mongoid::Timestamps

    field :domain, type: String
    field :certificate, type: String
    field :intermediaries, type: String
    field :key, type: String
    field :expires_at, type: DateTime
    field :renew_after, type: DateTime
    field :verification_path, type: String
    field :verification_string, type: String


    include CertificateVerifiable
    include CertificateIssuable

    validates :domain, presence: true, uniqueness: true

    # scope :active, -> { where('certificate IS NOT NULL AND expires_at > ?', Time.zone.now) }
    scope :active, -> { where(:certificate.ne => nil, :expires_at.gt => Time.zone.now) }
    # scope :renewable, -> { where('renew_after IS NULL OR renew_after <= ?', Time.zone.now) }
    scope :renewable, -> { self.or({ :renew_after => nil }, { :renew_after.lte => Time.zone.now }) }
    # scope :expired, -> { where('expires_at <= ?', Time.zone.now) }
    scope :expired, -> { where(:expires_at.lte => Time.zone.now) }

    before_create -> { self.key = OpenSSL::PKey::RSA.new(4096).to_s }
    after_save -> { save_to_redis }, if: -> { LetsEncrypt.config.use_redis? && active? }

    # Returns false if certificate is not issued.
    #
    # This method didn't check certificate is valid,
    # its only uses for checking is there has a certificate.
    def active?
      certificate.present?
    end

    # Returns true if certificate is expired.
    def expired?
      Time.zone.now >= expires_at
    end

    # Returns true if success get a new certificate
    def get
      verify && issue
    end

    def renew
      get
    end

    # Returns full-chain bundled certificates
    def bundle
      certificate + intermediaries
    end

    def certificate_object
      @certificate_object ||= OpenSSL::X509::Certificate.new(certificate)
    end

    def key_object
      @key_object ||= OpenSSL::PKey::RSA.new(key)
    end

    # Save certificate into redis
    def save_to_redis
      LetsEncrypt::Redis.save(self)
    end

    protected

    def logger
      LetsEncrypt.logger
    end
  end
end
