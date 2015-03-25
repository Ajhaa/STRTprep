##
## Step 2d - Decollapse sequences & alignments
##

rule /.step2d$/ => ['tmp/step2a', 'tmp/step2b.trace'] do |t|
  repacc2accpath = mymkfifo('step2d-')
  pid1 = spawn "gunzip -c #{t.sources[1]} > #{repacc2accpath}"

  libwellid = t.name.pathmap("%n")
  bcaccpath = mymkfifo('step2d-')
  pid2 = spawn <<EOF
gunzip -c #{t.source} \
| grep '^#{libwellid}\t'\
| gcut -f 2-4 \
| gsort -S #{1500*PROCS}M -k 1,1 > #{bcaccpath}
EOF

  sh <<EOF
gjoin -t '\t' -j 1 -o 1.2,2.1,2.2,2.3 #{repacc2accpath} #{bcaccpath}\
| gsort -S #{1500*PROCS}M -k 1,1\
| gzip -c > #{t.name}
EOF

  Process.waitpid(pid1)
  Process.waitpid(pid2)
end

#

def step2d_bam_sources(path)
  return ['tmp/step2c/accepted_hits.header',
          'tmp/step2c/accepted_hits.samUniqSortedByAcc',
          path.sub(/^out\/bam/, 'tmp').sub(/\.bam$/, '.step2d')]
end

rule /^out\/bam\/[^\/]+\.bam$/ => [->(path){ step2d_bam_sources(path) }] do |t|
  mkdir_p t.name.pathmap('%d')
  
  outfifo = mymkfifo('step2d-bam-')
  pid = spawn "samtools view -@ #{PROCS} -b #{outfifo} > #{t.name}"

  tmpfifo1 = mymkfifo('step2d-bam-')
  pid1 = spawn "gunzip -c #{t.sources[1]} > #{tmpfifo1}"

  tmpfifo2 = mymkfifo('step2d-bam-')
  pid2 = spawn "gunzip -c #{t.sources[2]} > #{tmpfifo2}"

  outfp = open(outfifo, 'w')
  infp = open(t.source)
  while line = infp.gets
    outfp.puts line
  end
  infp.close
  infp = open("| gjoin -t '\t' -j 1 #{tmpfifo1} #{tmpfifo2} | gsort -S #{3*PROCS} -k 3,3 -k 4,4n")
  while line = infp.gets
    cols = line.rstrip.split(/\t/)
    cols[0] = cols[-3]
    unless cols[11..-4].include?('XS:A:-')
      cols[9] = cols[-1]
      cols[10] = cols[-2]
    else
      cols[9] = cols[-1].reverse.tr('ACGT', 'TGCA')
      cols[10] = cols[-2].reverse
    end
    outfp.puts cols[0..-4].join("\t")
  end
  infp.close
  outfp.close

  Process.waitpid(pid)
  Process.waitpid(pid1)
  Process.waitpid(pid2)
end

#

rule '.step2d_cnt' => '.step2d' do |t|
  sh "gunzip -c #{t.source} | wc -l | gtr -d ' ' > #{t.name}"
end

#

task :clean_step2d do
  LIBIDS.each do |libid|
    rm_rf "tmp/#{libid}.*.step2d"
    rm_rf "out/bam/#{libid}.*.bam"
    rm_rf "tmp/#{libid}.*.step2d_cnt"
  end
end