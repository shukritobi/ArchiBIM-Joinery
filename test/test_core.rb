# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../archibim_joinery/core'

class ArchiBIMJoineryCoreTest < Minitest::Test
  C = SSDigitalLab::ArchiBIMJoinery::Core
  def pset(kind='base', **overrides)
    C.presets(kind).merge(overrides.transform_keys(&:to_s))
  end
  def part(p, key)
    C.parts(p).find { |x| x['key']==key }
  end

  def test_all_nine_joinery_families_generate
    C::KINDS.each do |kind|
      p = C.presets(kind)
      assert C.parts(p).size >= 3, "No parts for #{kind}"
      assert C.parts(p).all? { |item| item.values_at('w','d','h').all? { |n| n.positive? } }
    end
  end
  def test_base_cabinet_850_total_height_and_worktop
    p = C.presets('base')
    assert_equal 850, p['height']
    assert_equal 16, p['panel_thickness']
    assert_equal 100, p['toe_height']
    assert_equal 20, p['top_thickness']
    assert_equal 730, part(p,'side-left')['h']
    assert_equal 830, part(p,'worktop')['z']
    assert_equal 65, part(p,'kick')['y'] # 65 mm measured from finished front face
  end
  def test_wall_unit_is_600_above_base_worktop
    assert_equal 1450, C.presets('wall')['mount_height']
    assert_equal 850+600, C.presets('wall')['mount_height']
  end
  def test_adjusting_material_thickness_changes_parts
    p = pset('base', panel_thickness:20)
    assert_equal 20, part(p,'side-left')['w']
    assert_equal 560, part(p,'bottom')['w']
    assert_equal 560, part(p,'back')['w']
  end
  def test_desk_support_is_adjustable
    assert_equal 15, part(pset('desk'),'desk-support')['d']
    assert_equal 20, part(pset('desk',support_thickness:20),'desk-support')['d']
    assert_nil part(pset('desk'),'bottom')
  end
  def test_back_options
    assert_nil part(pset('wall',back:'none'),'back')
    assert_equal 334,part(pset('wall',back:'inset'),'back')['y']
    assert_equal 344,part(pset('wall',back:'applied'),'back')['y']
  end
  def test_drawers_contain_real_boxes
    p=pset('base', front:'drawers', drawer_count:3)
    assert part(p,'drawer-front-3')
    assert part(p,'drawer-left-1')
    assert part(p,'drawer-right-1')
    assert part(p,'drawer-bottom-2')
    assert_nil part(p,'shelf-1-1')
  end
  def test_combo_has_drawer_and_doors
    p=pset('base', front:'combo')
    assert part(p,'drawer-front-1')
    assert part(p,'door-1')
  end
  def test_fillers_and_end_panels
    p=pset('base',filler_left:50,filler_right:20,end_panel_left:true,end_panel_right:true)
    assert_equal 50,part(p,'filler-left')['w']
    assert part(p,'end-left')
    assert part(p,'end-right')
  end
  def test_physical_splash_panel_not_automatic_clearance
    assert_nil part(pset('base'),'backsplash')
    assert_equal 600,part(pset('base',backsplash_height:600),'backsplash')['h']
  end
  def test_invalid_dimensions_rejected
    assert_raises(ArgumentError) { C.normalize(pset('base',width:25)) }
    assert_raises(ArgumentError) { C.normalize(pset('base',panel_thickness:-1)) }
    assert_raises(ArgumentError) { C.normalize(pset('base',top_thickness:900)) }
    assert_raises(ArgumentError) { C.normalize(pset('base',width:Float::NAN)) }
  end
  def test_right_wall_side_orientation_and_offset
    wall={'start'=>[0.0,0.0],'end'=>[3000.0,0.0],'z'=>0,'thickness'=>150,'alignment'=>'center'}
    anchor={'station_mm'=>100.0,'side'=>'right','mount_height'=>0}
    tr=C.wall_frame(wall,anchor,600,600)
    assert_equal [100.0,-675.0,0.0], tr['origin']
    assert_equal [1.0,0.0,0.0],tr['xaxis']
    assert_equal [-0.0,1.0,0.0],tr['yaxis']
  end
  def test_left_side_flips_orientation_and_is_outside_wall
    wall={'start'=>[0.0,0.0],'end'=>[3000.0,0.0],'z'=>0,'thickness'=>150,'alignment'=>'center'}
    tr=C.wall_frame(wall,{'station_mm'=>100.0,'side'=>'left','mount_height'=>1450},600,600)
    assert_equal [700.0,675.0,1450.0],tr['origin']
    assert_equal [-1.0,-0.0,0.0],tr['xaxis']
    assert_equal [0.0,-1.0,0.0],tr['yaxis']
  end
  def test_stretch_binding_changes_width
    wall={'start'=>[0.0,0.0],'end'=>[2600.0,0.0],'z'=>0,'thickness'=>150,'alignment'=>'left'}
    anchor={'station_mm'=>100,'end_gap_mm'=>50,'side'=>'left','mode'=>'stretch','mount_height'=>0}
    p,frame=C.sync_binding(wall,pset('base'),anchor)
    assert_equal 2450.0,p['width']
    assert_equal [-1.0,0.0,0.0],frame['xaxis']
  end
  def test_fixed_binding_preserves_width
    wall={'start'=>[0.0,0.0],'end'=>[2600.0,0.0],'z'=>0,'thickness'=>150,'alignment'=>'center'}
    anchor={'station_mm'=>100,'end_gap_mm'=>50,'side'=>'right','mode'=>'fixed','mount_height'=>0}
    p,_frame=C.sync_binding(wall,pset('base'),anchor)
    assert_equal 600,p['width']
  end
  def test_out_of_wall_extent_raises_not_silently_shrinks
    wall={'start'=>[0.0,0.0],'end'=>[600.0,0.0],'z'=>0,'thickness'=>150,'alignment'=>'center'}
    assert_raises(ArgumentError) { C.wall_frame(wall,{'station_mm'=>100,'side'=>'right'},600,600) }
  end
  def test_finished_end_panels_do_not_overlap_carcass_sides
    p=pset('base',end_panel_left:true,end_panel_right:true)
    left=part(p,'side-left'); finish=part(p,'end-left')
    assert_equal finish['x']+finish['w'],left['x']
    right=part(p,'side-right'); finish_right=part(p,'end-right')
    assert_equal right['x']+right['w'],finish_right['x']
  end
  def test_overall_depth_includes_fronts
    p=pset('base', front:'doors')
    assert_equal 0,part(p,'door-1')['y']
    assert_equal 16,part(p,'side-left')['y']
    assert_equal 600,part(p,'side-left')['y']+part(p,'side-left')['d']
  end
  def test_internal_shelves_stop_at_inset_back
    p=pset('base')
    shelf=part(p,'shelf-1-1'); back=part(p,'back')
    assert_equal back['y'],shelf['y']+shelf['d']
  end
  def test_each_part_has_distinct_logical_key
    C::KINDS.each do |kind|
      keys=C.parts(C.presets(kind)).map { |p| p['key'] }
      assert_equal keys.size,keys.uniq.size,kind
    end
  end
end
