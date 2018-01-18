# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LetsEncrypt::RenewCertificatesJob, type: :job do
  before(:all) { ActiveJob::Base.queue_adapter = :test }

  it 'enqueue job' do
    expect { LetsEncrypt::RenewCertificatesJob.perform_later }
      .to have_enqueued_job(LetsEncrypt::RenewCertificatesJob)
  end

  describe 'starting renew' do
    let(:certificates) { [LetsEncrypt::Certificate.new] }

    it 'do nothing when success' do
      expect_any_instance_of(LetsEncrypt::Certificate).to receive(:renew).and_return(true)
      expect(LetsEncrypt::Certificate).to receive(:renewable).and_return(certificates)
      LetsEncrypt::RenewCertificatesJob.perform_now
    end

    it 'schedule next renew to 1 days from now' do
      allow_any_instance_of(LetsEncrypt::Certificate).to receive(:renew).and_return(false)
      expect_any_instance_of(LetsEncrypt::Certificate)
        .to receive(:update).with(renew_after: an_instance_of(ActiveSupport::TimeWithZone))
      expect(LetsEncrypt::Certificate).to receive(:renewable).and_return(certificates)

      LetsEncrypt::RenewCertificatesJob.perform_now
    end
  end
end
