# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../archibim_joinery/v04_features'

class JoineryV04FeaturesTest < Minitest::Test
  C=SSDigitalLab::ArchiBIMJoinery::Core

  def config(kind, **opts)
    C.presets(kind).merge(opts.transform_keys(&:to_s))
  end

  def parts(kind, **opts)
    C.parts(config(kind, **opts))
  end

  def test_basin_vanity_suspended_defaults_and_mirror
    p=C.normalize(config('basin_vanity'))
    assert_equal 450, p['mount_height']
    assert_equal 550, p['height']
    assert_equal 500, p['depth']
    assert_equal 0, p['top_shadow_gap']
    assert p['mirror_enabled']
    a=C.parts(p)
    assert a.any? { |x| x['role']=='mirror' }
    assert a.any? { |x| x['key']=='basin' && x['shape']=='basin_proxy' }
    assert a.any? { |x| x['role']=='worktop' }
    assert a.any? { |x| x['role']=='door' }
  end

  def test_basin_vanity_mount_and_basin_variants
    [300,450].each do |mount|
      a=parts('basin_vanity',mount_height:mount,basin_style:'inset',mirror_led:true)
      assert a.any? { |x| x['role']=='led' }
      assert a.any? { |x| x['key']=='basin' && x['h']==12 }
    end
    assert_equal 0,parts('basin_vanity',basin_style:'none',mirror_enabled:false).count{|x|%w[mirror basin].include?(x['role'])}
    assert_raises(ArgumentError) { parts('basin_vanity',basin_width:1200) }
  end

  def test_wall_panel_50_mm_kit
    p=C.normalize(config('wall_panel'))
    assert_equal 50,p['depth']
    assert_equal 2400,p['height']
    a=C.parts(p)
    assert_equal 1,a.count{|x|x['role']=='wall_panel'}
    assert a.any?{|x|x['key']=='panel-led-bottom'}
    assert_equal 0,a.count{|x|x['role']=='door'}
    assert a.all?{|x|x.values_at('w','d','h').all?{|n|n>0}}
  end

  def test_wall_panel_corners_and_customization
    a=parts('wall_panel',width:50,depth:50,height:2300,panel_led_bottom:false)
    assert_equal 1,a.count{|x|x['role']=='wall_panel'}
    assert_equal 50,a.first['w']
    b=parts('wall_panel',width:1500,wall_panel_gaps:3,panel_led_bottom:false,
            panel_led_top:true,panel_led_right:true)
    assert_equal 4,b.count{|x|x['role']=='wall_panel'}
    assert_equal 2,b.count{|x|x['role']=='led'}
    assert_raises(ArgumentError) { parts('wall_panel',width:40,wall_panel_gaps:3) }
  end

  def test_wall_and_tall_have_no_automatic_shadow_gap
    %w[wall tall wardrobe].each do |kind|
      p=C.normalize(config(kind))
      assert_equal 0,p['top_shadow_gap'],kind
      refute C.parts(p).any?{|part|part['role']=='door' && part['profile']=='edge_45_top'},kind
    end
    base=parts('base')
    assert_equal 20,C.normalize(config('base'))['top_shadow_gap']
    assert base.any?{|x|x['role']=='door'}
  end

  def test_tall_midheight_grip_height_and_depth
    p=config('tall',handle_style:'center_groove')
    a=C.parts(p)
    grooves=a.select{|x|x['role']=='door'}
    assert grooves.all?{|x|x['profile']=='center_groove'}
    assert grooves.all?{|x|x['groove_height']==20 && x['groove_depth']==10}
    assert_raises(ArgumentError) { C.parts(p.merge('groove_depth'=>20)) }
    assert_raises(ArgumentError) { C.parts(config('wall',handle_style:'center_groove')) }
  end

  def test_overhead_edge_grip_is_bottom_not_top
    a=parts('wall',handle_style:'edge_45')
    assert a.select{|x|x['role']=='door'}.all?{|x|x['profile']=='edge_45_bottom'}
    b=parts('tall',handle_style:'edge_45')
    assert b.select{|x|x['role']=='door'}.all?{|x|x['profile']=='edge_45_center'}
  end

  def test_all_new_families_are_normalizable
    %w[basin_vanity wall_panel].each do |kind|
      a=C.parts(C.presets(kind))
      assert_operator a.length,:>=,1
    end
  end
end
