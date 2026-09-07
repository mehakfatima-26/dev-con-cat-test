namespace :lead do
  desc "Delete a lead's certificate/credit_transactions/crm_records/layer_results/verification_run. Keeps the Lead row itself. Usage: rails lead:purge_records[L-XXXX]"
  task :purge_records, [ :lead_id ] => :environment do |_task, args|
    lead_id = args[:lead_id]
    abort "Usage: rails lead:purge_records[L-XXXX]" if lead_id.blank?

    lead = Lead.find_by(lead_id: lead_id)
    abort "No lead found with lead_id=#{lead_id}" unless lead

    run = lead.verification_run

    if run
      credit_count = run.credit_transactions.count
      layer_count = run.layer_results.count
      had_certificate = run.certificate.present?

      run.credit_transactions.destroy_all
      run.layer_results.destroy_all
      run.certificate&.destroy!
      run.reload
      run.destroy!

      puts "verification_run##{run.id}: destroyed #{credit_count} credit_transactions, #{layer_count} layer_results, certificate=#{had_certificate}"
    else
      puts "no verification_run for #{lead_id}"
    end

    crm_count = CrmRecord.where(lead_id: lead.id).count
    CrmRecord.where(lead_id: lead.id).destroy_all
    puts "crm_records: destroyed #{crm_count}"

    puts "done -- #{lead_id} itself was kept, only its dependent records were removed"
  end
end
