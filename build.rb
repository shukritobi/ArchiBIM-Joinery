# frozen_string_literal: true
require 'fileutils'
require 'tmpdir'
require 'zlib'
# ZIP packaging through system zip to avoid adding runtime dependencies to the extension.
ROOT=File.expand_path(__dir__)
OUT=File.join(ROOT,'dist','ArchiBIM_Joinery_v0.1.0.rbz')
FileUtils.mkdir_p(File.dirname(OUT))
Dir.chdir(ROOT) do
  abort 'zip executable not found' unless system('which zip > /dev/null 2>&1')
  FileUtils.rm_f(OUT)
  ok=system('zip','-q','-r',OUT,'ArchiBIM_Joinery.rb','archibim_joinery')
  abort 'RBZ packaging failed' unless ok
end
puts "Built #{OUT} (#{File.size(OUT)} bytes)"