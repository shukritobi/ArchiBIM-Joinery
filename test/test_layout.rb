# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../archibim_joinery/layout'

class JoineryLayoutV03Test < Minitest::Test
  C=SSDigitalLab::ArchiBIMJoinery::Core
  Planner=SSDigitalLab::ArchiBIMJoinery::PathPlanner

  def preset(kind='base',**opts)
    C.presets(kind).merge(opts.transform_keys(&:to_s))
  end

  def test_island_defaults_and_waterfall_miter_metadata
    p=C.normalize(preset('island'))
    assert_equal 600,p['depth']
    assert_equal 1000,p['height']
    assert_equal 50,p['top_thickness']
    assert p['waterfall_left']
    refute p['waterfall_right']
    assert_equal 'open',p['island_style']
    a=C.parts(p)
    assert_equal 'waterfall_top',a.find { |r| r['key']=='worktop' }['profile']
    assert_equal 'waterfall_left',a.find { |r| r['key']=='waterfall-left' }['profile']
    assert a.any? { |r| r['key']=='island-support-right' }
    assert a.any? { |r| r['key']=='island-low-back' }
    refute a.any? { |r| r['key']=='waterfall-right' }
    assert a.all? { |r| r.values_at('w','d','h').all? { |n| n > 0 } }
  end

  def test_island_both_ends_and_enclosed_carcass
    a=C.parts(preset('island',waterfall_right:true,island_style:'carcass',front:'doors'))
    assert_equal 2,a.count { |r| r['role']=='waterfall' }
    assert a.any? { |r| r['role']=='door' }
    refute a.any? { |r| r['key']=='end-right' }
    assert_raises(ArgumentError) { C.parts(preset('island',top_thickness:0)) }
  end

  def test_corner_filler_access_and_sizes
    %w[corner_base corner_wall corner_tall corner_desk].each do |kind|
      a=C.parts(preset(kind))
      assert a.any? { |r| r['key']=='corner-filler-front' },kind
      assert a.any? { |r| r['key']=='corner-filler-side' },kind
      assert a.any? { |r| r['key']=='corner-floor' },kind
      refute a.any? { |r| r['role']=='door' },kind
    end
    left=C.parts(preset('corner_base',corner_ownership:'left'))
    right=C.parts(preset('corner_base',corner_ownership:'right'))
    assert left.any? { |r| r['key']=='corner-door-front' }
    assert right.any? { |r| r['key']=='corner-door-side' }
    refute right.any? { |r| r['key']=='corner-side-right' },'side-access door must not overlap a solid side panel'
    assert_equal 50,left.find { |r| r['key']=='corner-filler-front' }['w']
  end

  def test_base_handleless_shadow_gap_and_end_panels
    p=preset('base')
    assert p['end_panel_left']
    assert p['end_panel_right']
    assert_equal 'none',p['handle_style']
    a=C.parts(p)
    assert_equal 2,a.count { |r| r['role']=='finish' }
    assert_equal 20,a.find { |r| r['key']=='end-left' }['w']
    assert_equal 20,a.find { |r| r['key']=='end-right' }['w']
    left=a.find { |r| r['key']=='side-left' }
    assert_equal 16,left['w']
    door=a.find { |r| r['role']=='door' }
    assert_in_delta 20,left['z']+left['h']-door['z']-door['h'],0.01
  end

  def test_modules_split_at_door_reveals_and_twin_sides
    p=preset('base',width:2400,front:'doors')
    a=C.parts(p)
    mods=a.select { |r| r['key'].match?(/module-\d+-left/) }
    assert_operator mods.size,:>=,2
    doors=a.select { |r| r['role']=='door' }
    assert_equal 4,doors.size
    mods.each do |mod|
      n=mod['module']
      left=mod['x']
      right=a.find { |r| r['key']=="module-#{n}-right" }['x']+p['panel_thickness']
      assert_operator right-left,:<=,1200.01
      assert doors.all? { |r| r['x']+r['w']<=left+0.01 || r['x']>=right-0.01 ||
                          (r['x']>=left && r['x']+r['w']<=right+0.01) }
    end
    assert_equal mods.size,a.count { |r| r['role']=='back' }
  end

  def test_reveal_aligned_module_boundaries_across_widths
    [1300, 1900, 2400, 2500, 3200, 4200].each do |width|
      a=C.parts(preset('base',width:width,front:'doors'))
      doors=a.select { |r| r['role']=='door' }
      modules=a.select { |r| r['key'].match?(/module-\\d+-left/) }
      assert modules.length>=2, "expected several carcasses at #{width}mm"
      modules.each do |side|
        n=side.fetch('module')
        right=a.find { |r| r['key']=="module-#{n}-right" }
        edge=right['x']+right['w']
        assert_operator edge-side['x'],:<=,1200.001
        assert doors.all? { |door|
          door['x']+door['w']<=side['x']+0.01 ||
            door['x']>=edge-0.01 ||
            (door['x']>=side['x']-0.01 && door['x']+door['w']<=edge+0.01)
        }, "Door cut by carcass boundary at width #{width}"
      end
    end
  end

  def test_modular_drawers_are_rebuilt_per_carcass
    p=preset('base',width:2400,front:'drawers',drawer_count:3)
    a=C.parts(p)
    count=a.count { |r| r['key'].match?(/module-\d+-left/) }
    assert_operator count,:>=,2
    assert_equal count*3,a.count { |r| r['role']=='drawer_front' }
    assert a.select { |r| r['role']=='drawer_front' }.all? { |r| r['w']<1200 }
  end

  def test_path_orthogonal_inside_and_outside_joins
    points=[[0,0,0],[3000,0,0],[3000,2400,0]]
    outside=Planner.plan(points,C.normalize(preset('base',path_side:'left')))
    assert_equal 2,outside['runs'].size
    assert_equal 1,outside['corners'].size
    assert_equal 'convex',outside['corners'][0]['turn']
    assert_in_delta 3000,outside['runs'][0]['length'],0.001
    assert_in_delta 2400,outside['runs'][1]['length'],0.001
    assert_equal [3000.0,-600.0,0.0],outside['corners'][0]['origin']
    inside=Planner.plan(points,C.normalize(preset('base',path_side:'right')))
    assert_equal 'concave',inside['corners'][0]['turn']
    assert_in_delta 2400,inside['runs'][0]['length'],0.001
    assert_in_delta 1800,inside['runs'][1]['length'],0.001
  end

  def test_line_alignment_and_connected_edges
    edges=[[[1000,0,0],[2000,0,0]],[[0,0,0],[1000,0,0]],
           [[2000,0,0],[2000,2000,0]]]
    paths=Planner.ordered_paths(edges)
    assert_equal 1,paths.size
    assert_equal 3,paths.first.size
    aligned=Planner.plan(paths.first,C.normalize(preset('base',path_alignment:'center')))
    assert_equal 2,aligned['runs'].size
    assert_equal 1,aligned['corners'].size
    assert_raises(ArgumentError) do
      Planner.ordered_paths(edges+[[[1000,0,0],[1000,500,0]]])
    end
  end

  def test_invalid_planes_angles_and_short_returns
    p=C.normalize(preset('base'))
    assert_raises(ArgumentError) { Planner.plan([[0,0,0],[3000,0,12]],p) }
    assert_raises(ArgumentError) { Planner.plan([[0,0,0],[3000,0,0],[4000,1000,0]],p) }
    assert_raises(ArgumentError) { Planner.plan([[0,0,0],[300,0,0],[300,150,0]],p) }
    assert_raises(ArgumentError) { C.normalize(preset('base',path_alignment:'diagonal')) }
    assert_raises(ArgumentError) { C.normalize(preset('corner_base',corner_filler:400)) }
  end
end
