# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'stringio'
require_relative '../archibim_joinery/report_zip'

class JoineryDiagnosticZipTest < Minitest::Test
  Z=SSDigitalLab::ArchiBIMJoinery::ReportZip

  def test_zip_headers_and_central_directory
    entries={'DIAGNOSIS_REPORT.json'=>'{"ok":true}',
             'UI_REPORT.txt'=>"clicked\nsaved\n",
             'SketchUp_View.png'=>"\x89PNG\r\n".b}
    bytes=Z.encode(entries)
    assert_equal "PK\x03\x04".b,bytes.byteslice(0,4)
    assert_equal "PK\x05\x06".b,bytes.byteslice(-22,4)
    tail=bytes.byteslice(-22,22).unpack('VvvvvVVv')
    assert_equal 3,tail[3]
    assert_equal 3,tail[4]
    assert_equal "PK\x01\x02".b,bytes.byteslice(tail[6],4)
    entries.each_key{|name|assert_includes bytes,name}
    assert_equal entries.length,bytes.scan("PK\x03\x04".b).length
  end

  def test_unzip_external_reader_when_available
    skip 'unzip not installed' unless system('which unzip >/dev/null 2>&1')
    Dir.mktmpdir do |dir|
      path=File.join(dir,'ArchiBIM_Joinery_QA_LATEST.zip')
      File.binwrite(path,Z.encode({'alpha.txt'=>'hello','beta.txt'=>"world\n"}))
      assert system('unzip','-tq',path,out:File::NULL), 'ZIP must be readable by standard unzip'
    end
  end

  def test_zip_path_traversal_protection
    assert_raises(ArgumentError){Z.encode({'../unsafe.txt'=>'payload'})}
    assert_raises(ArgumentError){Z.encode({'/root.txt'=>'payload'})}
    assert_raises(ArgumentError){Z.encode({'bad\\file'=>'payload'})}
  end
end
