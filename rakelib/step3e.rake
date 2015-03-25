##
## Step 3e - QC statistics
##

require 'csv'

step3e_sources = ['src/samples.csv']
LIBWELLIDS.each do |libwellid|
  step3e_sources.push("tmp/#{libwellid}.step2d_cnt")
  step3e_sources.push("tmp/#{libwellid}.step2e_cnt")
  step3e_sources.push("tmp/#{libwellid}.step2f_cnt")
  step3e_sources.push("tmp/cg/#{libwellid}.step3b_cnt")
  step3e_sources.push("tmp/cg/#{libwellid}.step3c_cnt")
end

file 'tmp/cg/samples.txt' => step3e_sources do |t|
  libwellid2name = Hash.new
  samples = CSV.table(t.source)
  samples.each do |row|
    libwellid2name["#{row[:library]}.#{row[:well]}"] = row[:name]
  end

  outfp = open(t.name, 'w')
  outfp.puts ['LIBRARY', 'WELL', 'NAME',
              'QUALIFIED_READS', 'REDUNDANCY',
              'TOTAL_READS', 'MAPPED_READS', 'MAPPED_RATE',
              'SPIKEIN_READS', 'MAPPED/SPIKEIN',
              'SPIKEIN_5END_READS', 'SPIKEIN_5END_RATE',
              'CODING_READS', 'CODING_5END_READS', 'CODING_5END_RATE'
             ].join("\t")
  LIBWELLIDS.each do |libwellid|
    infp = open("tmp/#{libwellid}.step2d_cnt")
    tmp = infp.gets.rstrip
    infp.close
    reads_total = tmp.to_i

    infp = open("tmp/#{libwellid}.step2e_cnt")
    tmp = infp.gets.rstrip.split("\t")
    infp.close
    reads_mapped = tmp[0].to_i
    reads_mapped_spike = tmp[1].to_i

    infp = open("tmp/#{libwellid}.step2f_cnt")
    tmp = infp.gets.rstrip.split("\t")
    infp.close
    reads_qualified = tmp[0].to_i
    
    infp = open("tmp/cg/#{libwellid}.step3b_cnt")
    tmp = infp.gets.rstrip.split("\t")
    infp.close
    reads_mapped_coding_5utr = tmp[0].to_i
    reads_mapped_spike_5end = tmp[1].to_i

    infp = open("tmp/cg/#{libwellid}.step3c_cnt")
    tmp = infp.gets.rstrip.split("\t")
    infp.close
    reads_mapped_coding_exon = tmp[0].to_i
    
    libid, wellid = libwellid.split('.')
    outfp.puts [
      libid,
      wellid,
      libwellid2name.key?(libwellid) ? libwellid2name[libwellid] : 'NA',
      reads_qualified,
      reads_total,
      reads_total > 0 ? reads_qualified.to_f/reads_total : 'NA',
      reads_mapped,
      reads_total > 0 ? reads_mapped.to_f/reads_total : 'NA',
      reads_mapped_spike,
      reads_mapped_spike > 0 ? reads_mapped.to_f/reads_mapped_spike : 'NA',
      reads_mapped_spike_5end,
      reads_mapped_spike > 0 ? reads_mapped_spike_5end.to_f/reads_mapped_spike : 'NA',
      reads_mapped_coding_exon,
      reads_mapped_coding_5utr,
      reads_mapped_coding_exon > 0 ? reads_mapped_coding_5utr.to_f/reads_mapped_coding_exon : 'NA'
    ].join("\t")
  end
  outfp.close
end

file 'out/cg/samples.txt' => 'tmp/cg/samples.txt' do |t|
  sh "R --vanilla --quiet < bin/_step3e_check_outliers.R > #{t.name}.log 2>&1"
end
