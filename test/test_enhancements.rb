# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../archibim_joinery/enhancements'
require_relative '../archibim_joinery/drafting'

class JoineryEnhancementsTest < Minitest::Test
  C=SSDigitalLab::ArchiBIMJoinery::Core
  D=SSDigitalLab::ArchiBIMJoinery::Drafting
  def params(kind='base', **kw)
    C.presets(kind).merge(kw.transform_keys(&:to_s))
  end
  def parts(kind='base', **kw)
    C.parts(params(kind,**kw))
  end
  def part(xs,key)
    xs.find { |p| p['key']==key }
  end
  def test_floor_length_finishes_default_and_opt_out
    a=parts('base',filler_left:50,end_panel_right:true)
    assert_equal 0,part(a,'filler-left')['z']
    assert_equal 0,part(a,'end-right')['z']
    assert_equal 830,part(a,'filler-left')['h']
    b=parts('base',filler_left:50,end_panel_right:true,floor_finish_panels:false)
    assert_equal 100,part(b,'filler-left')['z']
  end
  def test_door_width_ceiling_automatically_increases_leaf_count
    {'base'=>600,'tall'=>900}.each do |kind,w|
      p=params(kind,width:w,front:'doors')
      actual=C.normalize(p)
      leafs=C.parts(actual).select { |x| x['role']=='door' }
      assert leafs.all? { |door| door['w'] <= 600 }
      assert_equal 2,leafs.size if w==900
    end
    p=C.normalize(params('base',width:1300,front:'doors'))
    assert_equal 3,p['door_count']
    assert_equal 3,C.parts(p).count { |v| v['role']=='door' }
  end
  def test_hardware_and_mitred_edge
    p=parts('base',handle_style:'bar')
    assert p.any? { |v| v['role']=='handle' }
    profile=parts('base',handle_style:'edge_45').find { |v| v['role']=='door' }
    assert_equal 'edge_45_top',profile['profile']
    assert profile['bevel_mm'] > 0
    assert_equal 0,parts('base',handle_style:'none').count { |v| v['role']=='handle' }
  end
  def test_boxup_height_tracks_ceiling
    p=parts('wall',box_up:true,ceiling_height:3000)
    f=part(p,'boxup-front')
    assert_in_delta 830,f['h']
    assert_equal 720,f['z']
    assert_raises(ArgumentError) { C.parts(params('wall',box_up:true,ceiling_height:2000)) }
  end
  def test_appliance_openings_are_not_blocked_by_back_panels
    C::APPLIANCES.each do |kind|
      p=C.presets(kind)
      xs=C.parts(p)
      assert xs.any? { |v| v['key']=='niche-bottom' }
      assert xs.any? { |v| v['key']=='niche-top' }
      refute xs.any? { |v| v['key']=='back' },kind
      assert xs.all? { |v| v.values_at('w','d','h').all? { |n| n > 0 } },kind
    end
    fridge=parts('fridge_tall')
    assert fridge.any? { |v| v['key'].start_with?('upper-door-') }
    assert_equal 0,parts('fridge_tall',upper_storage:'open').count { |v| v['role']=='door' }
    assert_raises(ArgumentError) { C.parts(params('oven_tall',appliance_width:900)) }
  end
  def test_nearest_archibim_wall_orientation_and_fallback
    wall={'id'=>'wall-1','start'=>[0.0,0.0],'end'=>[3000.0,0.0],
          'z'=>0,'thickness'=>150,'alignment'=>'center'}
    p=C.normalize(params)
    candidate=C.find_near_wall([wall],[500,80],p)
    assert_equal 'left',candidate['side']
    assert_equal 500,candidate['station_mm']
    assert_nil C.find_near_wall([wall],[500,1000],p)
  end
  def test_dxf_has_dashed_opening_layer_and_two_views
    x=D.dxf(params('base',width:1300,front:'doors'),'test-123')
    assert_includes x,'ABJ_ELEVATION_OPENING'
    assert_includes x,'DASHED'
    assert_includes x,'ABJ_PLAN'
    assert_includes x,'AC1009'
    assert_equal 6,D.opening_segments(params('base',width:1300,front:'doors')).size
  end
  def test_invalid_options_rejected
    assert_raises(ArgumentError) { C.normalize(params('base',handle_style:'welded')) }
    assert_raises(ArgumentError) { C.normalize(params('fridge_tall',upper_storage:'magic')) }
  end
end
