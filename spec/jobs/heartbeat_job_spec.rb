# frozen_string_literal: true

require 'spec_helper'

describe HeartbeatJob do
  context "with time frozen" do
    let(:run_time) { Time.zone.local(2016, 4, 13, 13, 0, 0) }

    before { Spree::Config.last_job_queue_heartbeat_at = nil }

    around do |example|
      Timecop.freeze(run_time) { example.run }
    end

    it "updates the last_job_queue_heartbeat_at config var" do
      run_job
      expect(Time.parse(Spree::Config.last_job_queue_heartbeat_at).in_time_zone).to eq(run_time)
    end
  end

  private

  def run_job
    clear_jobs
    HeartbeatJob.perform_now
    flush_jobs ignore_exceptions: false
  end
end
