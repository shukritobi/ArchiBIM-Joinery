# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../archibim_joinery/drafting'
require_relative '../archibim_joinery/scale_math'

class JoineryV021Test < Minitest::Test
  C=SSDigitalLab::ArchiBIMJoinery::Core
  D=SSDigitalLab::ArchiBIMJoinery::Drafting
  S=SSDigitalLab::ArchiBIMJoinery::ScaleMath
  def pset(kind='base',**overrides)
    C.presets(kind).merge(overrides.transform_keys(&:to_s))
  end
  def part(p,key)
    C.parts(p).find { |n| n['key']==key }
  end
  def test_all_twelve_families_generate
    assert_equal 12,C::KINDS.size
    C::KINDS.each { |kind| assert_operator C.parts(C.presets(kind)).length,:>,2 }
  end
  def test_drawer_shadow_gap_equal_across_tiers
    p=pset('base',front:'drawers',drawer_count:3,drawer_shadow_gap:20)
    fronts=C.parts(p).select { |n| n['role']=='drawer_front' }.sort_by { |n| n['z'] }
    assert_equal 3,fronts.size
    assert_in_delta 20,fronts[1]['z']-fronts[0]['z']-fronts[0]['h'],0.001
    assert_in_delta 20,fronts[2]['z']-fronts[1]['z']-fronts[1]['h'],0.001
    assert_raises(ArgumentError) { C.parts(p.merge('drawer_shadow_gap'=>400)) }
  end
  def test_top_edge_grip_has_twenty_mm_reveal
    p=pset('base',handle_style:'edge_45')
    door=part(p,'door-1')
    assert_equal 'edge_45_top',door['profile']
    top=part(p,'side-left')['z']+part(p,'side-left')['h']
    assert_in_delta 20,top-door['z']-door['h'],0.001
    drawers=C.parts(pset('base',front:'drawers',handle_style:'edge_45')).select { |r| r['role']=='drawer_front' }
    assert drawers.all? { |r| r['profile']=='edge_45_top' }
  end
  def test_round_hardware_metadata
    %w[bar knob].each do |style|
      handles=C.parts(pset('base',handle_style:style)).select { |r| r['role']=='handle' }
      assert_operator handles.length,:>,0
      assert handles.all? { |r| r['shape']=='cylinder' }
    end
  end
  def test_runner_variants_and_cutlist
    p=pset('base',front:'drawers')
    side=C.parts(p.merge('runner_type'=>'side_mount'))
    movento=C.parts(p.merge('runner_type'=>'blum_movento'))
    assert_equal 6,side.count { |r| r['role']=='drawer_runner' }
    assert_operator movento.find { |r| r['key']=='drawer-left-1' }['x'],:<,
                    side.find { |r| r['key']=='drawer-left-1' }['x']
    refute C.cutlist(p.merge('runner_type'=>'side_mount')).any? { |r| r['role']=='drawer_runner' }
    assert_raises(ArgumentError) { C.parts(p.merge('runner_type'=>'side_mount','runner_length'=>700)) }
  end
  def test_skirting_size_and_thickness_track_countertop
    p=pset('base',top_skirting:true,top_skirting_height:50,top_thickness:25)
    assert_equal 25,part(p,'top-skirting')['d']
    assert_equal 50,part(p,'top-skirting')['h']
    assert_equal 850,part(p,'top-skirting')['z']
    assert_raises(ArgumentError) { C.normalize(pset('wall',top_skirting:true)) }
  end
  def test_absorb_native_scale_dimensions_without_thickness_change
    p=pset('base',panel_thickness:16)
    q=S.apply_dimensions(p,[3.38,1.5,0.8])
    assert_in_delta 2028,q['width'],0.01
    assert_equal 900,q['depth']
    assert_equal 680,q['height']
    assert_equal 16,q['panel_thickness']
    assert S.changed?([1,3.38,1])
    refute S.changed?([1,1,1])
    assert_raises(ArgumentError) { S.apply_dimensions(p,[1,0,1]) }
  end
  def test_dxf_elevation_and_plan_include_drawer_symbols
    p=pset('base',front:'drawers')
    assert_equal 6,D.opening_segments(p).length
    assert D.plan_segments(p).any? { |r| r[4]=='ABJ_PLAN_DRAWERS' }
    dxf=D.dxf(p,'cabinet-1')
    assert_includes dxf,'ABJ_PLAN_DRAWERS'
    assert_includes dxf,'ABJ_ELEVATION_DRAWERS'
    assert_includes dxf,'DASHED'
  end
  def test_combo_family_retains_drawer_and_doors
    a=C.parts(pset('base',front:'combo'))
    assert a.any? { |r| r['role']=='drawer_front' }
    assert a.any? { |r| r['role']=='door' }
  end
end
