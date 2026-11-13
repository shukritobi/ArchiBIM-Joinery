# frozen_string_literal: true
# Pure Ruby model of panel-built joinery. Coordinates are millimetres.
require 'json'

module SSDigitalLab
  module ArchiBIMJoinery
    module Core
      SCHEMA = 1
      KINDS = %w[base wall tall desk wardrobe vanity bookcase tv_console reception].freeze
      FRONTS = %w[open doors drawers combo].freeze
      BACKS = %w[inset applied none].freeze
      MODES = %w[fixed stretch].freeze

      PRESETS = {
        'base'       => { 'width'=>600, 'height'=>850, 'depth'=>600, 'toe_height'=>100, 'top_thickness'=>20, 'front'=>'doors', 'shelves'=>1 },
        'wall'       => { 'width'=>600, 'height'=>720, 'depth'=>350, 'toe_height'=>0, 'top_thickness'=>0, 'front'=>'doors', 'shelves'=>1 },
        'tall'       => { 'width'=>600, 'height'=>2400, 'depth'=>600, 'toe_height'=>100, 'top_thickness'=>0, 'front'=>'doors', 'shelves'=>4 },
        'desk'       => { 'width'=>1200, 'height'=>750, 'depth'=>600, 'toe_height'=>0, 'top_thickness'=>25, 'front'=>'open', 'shelves'=>0 },
        'wardrobe'   => { 'width'=>1200, 'height'=>2400, 'depth'=>600, 'toe_height'=>100, 'top_thickness'=>0, 'front'=>'doors', 'shelves'=>2 },
        'vanity'     => { 'width'=>900, 'height'=>850, 'depth'=>500, 'toe_height'=>100, 'top_thickness'=>20, 'front'=>'drawers', 'shelves'=>0 },
        'bookcase'   => { 'width'=>900, 'height'=>2100, 'depth'=>320, 'toe_height'=>0, 'top_thickness'=>0, 'front'=>'open', 'shelves'=>5 },
        'tv_console' => { 'width'=>1800, 'height'=>500, 'depth'=>450, 'toe_height'=>80, 'top_thickness'=>20, 'front'=>'doors', 'shelves'=>1 },
        'reception'  => { 'width'=>1800, 'height'=>1100, 'depth'=>650, 'toe_height'=>100, 'top_thickness'=>25, 'front'=>'open', 'shelves'=>1 }
      }.freeze
      COMMON = {
        'panel_thickness'=>16, 'back_thickness'=>6, 'back_recess'=>10, 'front_thickness'=>16,
        'support_thickness'=>15, 'toe_recess'=>65, 'door_gap'=>2, 'drawer_count'=>3,
        'door_count'=>2, 'divisions'=>0, 'front'=>'open', 'back'=>'inset',
        'filler_left'=>0, 'filler_right'=>0, 'end_panel_left'=>false,
        'end_panel_right'=>false, 'material'=>'White Melamine', 'top_material'=>'Countertop',
        'mount_height'=>0, 'backsplash_height'=>0, 'name'=>''
      }.freeze

      def self.presets(kind)
        raise ArgumentError, "Unknown joinery type: #{kind}" unless KINDS.include?(kind)
        h = JSON.parse(JSON.generate(COMMON.merge(PRESETS.fetch(kind))))
        h['kind'] = kind
        h['mount_height'] = 1450 if kind == 'wall' # 850 worktop + 600 clear gap
        h['back'] = 'none' if kind == 'desk'
        h['door_count'] = 2 if h['width'] >= 800
        h['door_count'] = 1 if h['width'] < 800
        h['name'] = kind.split('_').map(&:capitalize).join(' ') + ' Unit'
        h
      end

      def self.value(raw, key, min, max)
        x = Float(raw.fetch(key))
        raise ArgumentError, "#{key} must be finite" unless x.finite?
        raise ArgumentError, "#{key} outside #{min}..#{max} mm" unless x >= min && x <= max
        x
      rescue TypeError, KeyError
        raise ArgumentError, "Missing or invalid #{key}"
      end

      def self.integer(raw, key, min, max)
        x = Integer(raw.fetch(key))
        raise ArgumentError, "#{key} must be #{min}..#{max}" unless x.between?(min, max)
        x
      rescue TypeError, KeyError
        raise ArgumentError, "Missing or invalid #{key}"
      end

      def self.normalize(raw)
        raise ArgumentError, 'Expected joinery configuration object' unless raw.is_a?(Hash)
        kind = raw.fetch('kind', 'base').to_s
        h = presets(kind).merge(raw.transform_keys(&:to_s))
        h['kind'] = kind
        %w[width height depth panel_thickness front_thickness back_thickness back_recess
           toe_height toe_recess top_thickness support_thickness door_gap filler_left
           filler_right mount_height backsplash_height].each do |k|
          lower = %w[width height depth panel_thickness front_thickness support_thickness].include?(k) ? 1.0 : 0.0
          h[k] = value(h, k, lower, k == 'mount_height' ? 25_000 : 100_000)
        end
        %w[shelves drawer_count door_count divisions].each { |k| h[k] = integer(h, k, 0, 40) }
        h['door_count'] = integer(h, 'door_count', 1, 12) if %w[doors combo].include?(h['front'])
        raise ArgumentError, 'Unsupported front' unless FRONTS.include?(h['front'])
        raise ArgumentError, 'Unsupported back construction' unless BACKS.include?(h['back'])
        %w[end_panel_left end_panel_right].each { |k| h[k] = h[k] == true || h[k] == 'true' }
        h['name'] = h.fetch('name', '').to_s.strip[0, 120]
        h['shelves'] = 0 if h['front'] == 'drawers'
        h['material'] = h.fetch('material', 'White Melamine').to_s[0, 120]
        h['top_material'] = h.fetch('top_material', 'Countertop').to_s[0, 120]
        h['end_panel_thickness'] = value(h,'end_panel_thickness',1,100_000) if h.key?('end_panel_thickness')
        end_t = h.fetch('end_panel_thickness',h['panel_thickness'])
        w = h['width'] - h['filler_left'] - h['filler_right'] - end_t * (((h['end_panel_left'] ? 1 : 0) + (h['end_panel_right'] ? 1 : 0)))
        t = h['panel_thickness']
        raise ArgumentError, 'Width too small for carcass and fillers' if w < (h['kind'] == 'wall_panel' ? 30 : (t * (h['divisions'] + 2)) + 100)
        raise ArgumentError, 'Depth too small for carcass and back' if h['depth'] < [t * 4, h['back_thickness'] + h['back_recess'] + 30].max
        raise ArgumentError, 'Toe recess exceeds cabinet depth' if h['toe_recess'] + h['panel_thickness'] + h['front_thickness'] > h['depth']
        raise ArgumentError, 'Back panel recess exceeds cabinet depth' if h['back'] != 'none' && h['back_thickness'] + h['back_recess'] + 2*t > h['depth']
        raise ArgumentError, 'Front reveals too large' if h['front'] != 'open' && h['door_gap'] * (h['door_count'] + 1) >= w
        case_height = h['height'] - h['top_thickness'] - h['toe_height']
        raise ArgumentError, 'Height too small for toe kick and countertop' if case_height < 2 * t + 80
        raise ArgumentError, 'Shelves too numerous for cabinet height' if h['shelves'] > 0 && case_height / (h['shelves'] + 1) < 40
        raise ArgumentError, 'Drawer configuration needs at least one drawer' if h['front'] == 'drawers' && h['drawer_count'] < 1
        raise ArgumentError, 'Drawer configuration cannot fit vertically' if %w[drawers combo].include?(h['front']) && (case_height - 2 * t) / h['drawer_count'].to_f < 90
        h
      end

      # Each part has deterministic role key and a rectangular bounding box in local coords.
      # x=width, y=front->rear, z=floor->ceiling. Units: mm.
      def self.parts(raw)
        p = normalize(raw)
        result = []
        append = lambda do |key, label, x, y, z, w, d, h, role='carcass', material=nil|
          next if [w,d,h].any? { |n| n <= 0.01 }
          raise ArgumentError, "Invalid #{label} geometry" unless [x,y,z,w,d,h].all?(&:finite?)
          result << { 'key'=>key, 'name'=>label, 'role'=>role, 'material'=>material || p['material'],
                      'x'=>x.round(4), 'y'=>y.round(4), 'z'=>z.round(4),
                      'w'=>w.round(4), 'd'=>d.round(4), 'h'=>h.round(4) }
        end
        t = p['panel_thickness']; ft = p['front_thickness']; gap = p['door_gap']
        et = p.fetch('end_panel_thickness',t)
        x0 = p['filler_left'] + (p['end_panel_left'] ? et : 0)
        cw = p['width'] - p['filler_left'] - p['filler_right'] - (p['end_panel_left'] ? et : 0) - (p['end_panel_right'] ? et : 0)
        floor_z = p['toe_height']; ch = p['height'] - floor_z - p['top_thickness']
        depth = p['depth']; is_desk = p['kind'] == 'desk'
        case_y = p['front'] == 'open' ? 0.0 : ft
        case_d = depth - case_y
        raise ArgumentError, 'Overall depth is too small for fronts and carcass' if case_d <= 2*t
        append.call('side-left', 'Left Carcass Side', x0, case_y, floor_z, t, case_d, ch)
        append.call('side-right', 'Right Carcass Side', x0+cw-t, case_y, floor_z, t, case_d, ch)
        unless is_desk
          append.call('bottom', 'Carcass Bottom', x0+t, case_y, floor_z, cw-2*t, case_d, t)
          append.call('top', 'Carcass Top', x0+t, case_y, floor_z+ch-t, cw-2*t, case_d, t)
        end
        if p['toe_height'] > 0
          append.call('kick', 'Recessed Toe Kick', x0, p['toe_recess'],
                      0, cw, t, p['toe_height'], 'toe_kick')
        end
        if p['top_thickness'] > 0
          append.call('worktop', 'Countertop / Worktop', 0, 0, p['height']-p['top_thickness'],
                      p['width'], depth, p['top_thickness'], 'worktop', p['top_material'])
        end
        shelf_depth = (p['back'] == 'none' ? case_d : depth - (p['back'] == 'inset' ? p['back_recess'] + p['back_thickness'] : p['back_thickness']) - case_y)
        if is_desk
          st = p['support_thickness']
          append.call('desk-support', 'Desk Back Support', x0+t, depth-st,
                      p['height']-p['top_thickness']-120, cw-2*t, st, 120, 'support')
        else
          if p['back'] != 'none'
            by = p['back'] == 'inset' ? depth - p['back_recess'] - p['back_thickness'] : depth - p['back_thickness']
            append.call('back', 'Carcass Back Panel', x0+t, by, floor_z+t, cw-2*t,
                        p['back_thickness'], ch-2*t, 'back')
          end
          body = cw - 2*t
          p['divisions'].times do |i|
            px = x0+t + (body-t*p['divisions'])*(i+1)/(p['divisions']+1.0) + t*i
            append.call("division-#{i+1}", "Upright Divider #{i+1}", px, case_y, floor_z+t, t, shelf_depth, ch-2*t)
          end
          bay_width = (body - t*p['divisions']) / (p['divisions']+1.0)
          (p['divisions']+1).times do |bay|
            bay_x = x0+t + bay*(bay_width+t)
            p['shelves'].times do |i|
              sz = floor_z+t + (ch-2*t)*(i+1)/(p['shelves']+1.0) - t/2.0
              append.call("shelf-#{bay+1}-#{i+1}", "Shelf #{bay+1}.#{i+1}", bay_x, case_y, sz, bay_width, shelf_depth, t, 'shelf')
            end
          end
          front_height = ch - 2*gap
          front_bottom = floor_z + gap
          case p['front']
          when 'doors'
            doors(result, append, x0, cw, front_bottom, front_height, ft, gap, p['door_count'])
          when 'drawers'
            drawers(append, p, x0, cw, front_bottom, front_height, ft, gap, 0)
          when 'combo'
            upper = [front_height * 0.3, 130.0].max
            upper = [upper, front_height*0.5].min
            drawers(append, p.merge('drawer_count'=>1), x0, cw, front_bottom+front_height-upper,
                    upper, ft, gap, 0)
            doors(result, append, x0, cw, front_bottom, front_height-upper-gap, ft, gap, p['door_count'])
          end
        end
        if p['filler_left'] > 0
          append.call('filler-left', 'Left Scribe / Filler', 0, 0, floor_z, p['filler_left'], t, ch, 'filler')
        end
        if p['filler_right'] > 0
          append.call('filler-right', 'Right Scribe / Filler', p['width']-p['filler_right'], 0, floor_z,
                      p['filler_right'], t, ch, 'filler')
        end
        if p['end_panel_left']
          append.call('end-left', 'Finished Left End Panel', p['filler_left'], 0, floor_z, et, depth, ch, 'finish')
        end
        if p['end_panel_right']
          append.call('end-right', 'Finished Right End Panel', p['width']-p['filler_right']-et, 0, floor_z,
                      et, depth, ch, 'finish')
        end
        if p['backsplash_height'] > 0
          append.call('backsplash', 'Physical Backsplash', 0, depth-t, p['height'], p['width'], t,
                      p['backsplash_height'], 'backsplash', p['top_material'])
        end
        result
      end

      def self.doors(_result, append, x0, width, z, height, t, gap, count)
        segment = (width - (count+1)*gap)/count.to_f
        count.times do |i|
          append.call("door-#{i+1}", "Door Leaf #{i+1}", x0+gap+i*(segment+gap), 0,
                      z, segment, t, height, 'door')
        end
      end

      def self.drawers(append, p, x0, cw, z, height, t, gap, index_offset)
        n = p['drawer_count']
        # Keep each reveal the same, including the top grip/shadow gap.
        shadow_gap = p.fetch('drawer_shadow_gap', gap).to_f
        front_each = (height - n*shadow_gap)/n.to_f
        raise ArgumentError, 'Drawer shadow gaps exceed available height' if front_each < 65
        panel = p['panel_thickness']
        available = cw-2*panel
        runner = p.fetch('runner_type', 'generic')
        clearance = if %w[blum_movento hettich_quadro].include?(runner)
                      # Indicative 16 mm wooden drawer-box deduction based on 21 mm
                      # inside width rule; verify exact runner and mounting variant.
                      21.0-panel
                    else
                      p.fetch('runner_clearance', 13.0).to_f
                    end
        raise ArgumentError, 'Invalid runner side clearance for panel thickness' if clearance < 1
        box_w = available - 2*clearance
        max_depth = [p['depth'] - t - 45.0, 120.0].max
        length = p.fetch('runner_length', 450).to_f
        box_d = %w[generic none].include?(runner) ? max_depth : [max_depth,length - 10.0].min
        raise ArgumentError, 'Selected runner is too long for cabinet depth' if runner != 'none' && runner != 'generic' && length > max_depth + 20
        n.times do |i|
          idx = i+index_offset+1
          zz = z+i*(front_each+shadow_gap)
          append.call("drawer-front-#{idx}", "Drawer Front #{idx}", x0+gap, 0, zz,
                      cw-2*gap, t, front_each, 'drawer_front')
          box_z = zz + [front_each*0.15, 20.0].max
          box_h = [front_each*0.65, 160.0].min
          if box_h > 2*panel+10 && box_w > 2*panel+40
            bx = x0+panel+clearance
            append.call("drawer-left-#{idx}", "Drawer #{idx} Left Side", bx, t+15, box_z,
                        panel, box_d, box_h, 'drawer_box')
            append.call("drawer-right-#{idx}", "Drawer #{idx} Right Side", bx+box_w-panel,
                        t+15, box_z, panel, box_d, box_h, 'drawer_box')
            append.call("drawer-back-#{idx}", "Drawer #{idx} Back", bx+panel, t+15+box_d-panel,
                        box_z, box_w-2*panel, panel, box_h, 'drawer_box')
            append.call("drawer-bottom-#{idx}", "Drawer #{idx} Bottom", bx+panel, t+15+panel,
                        box_z, box_w-2*panel, box_d-2*panel, [p['back_thickness'], 6].max,
                        'drawer_bottom')
            if runner != 'none' && runner != 'generic'
              # Two simplified rail bodies for coordination / 2D detailing. These
              # are NOT a manufacturer's manufacturing or drilling template.
              rail_d = [length, max_depth].min
              rail_z = box_z + 4
              append.call("runner-left-#{idx}", "Left Drawer Runner #{idx}", x0+panel, t+17,
                          rail_z, [clearance, 6].min, rail_d, 8, 'drawer_runner')
              append.call("runner-right-#{idx}", "Right Drawer Runner #{idx}", x0+cw-panel-[clearance,6].min, t+17,
                          rail_z, [clearance, 6].min, rail_d, 8, 'drawer_runner')
            end
          end
        end
      end

      def self.cutlist(raw)
        parts(raw).map do |part|
          dims = [part['w'],part['d'],part['h']].sort.reverse
          { 'part'=>part['name'], 'role'=>part['role'], 'material'=>part['material'],
            'length_mm'=>dims[0], 'width_mm'=>dims[1], 'thickness_mm'=>dims[2],
            'edge_banding'=>'TBD', 'quantity'=>1 }
        end
      end

      def self.face_offsets(wall)
        t = Float(wall.fetch('thickness'))
        case wall.fetch('alignment', 'center')
        when 'right' then [-t, 0.0]
        when 'left' then [0.0, t]
        else [-t/2.0, t/2.0]
        end
      end

      # Returns a SketchUp-independent coordinate frame. Cabinet's local Y goes
      # FRONT -> BACK, so its back meets the wall face, not its front.
      def self.wall_frame(wall, anchor, width, depth)
        start = wall.fetch('start'); finish = wall.fetch('end')
        dx = finish[0]-start[0]; dy = finish[1]-start[1]
        length = Math.hypot(dx,dy)
        raise ArgumentError, 'Wall length invalid' if length < 50
        ux = dx/length; uy = dy/length; nx = -uy; ny = ux
        side = anchor.fetch('side', 'left')
        raise ArgumentError, 'Side must be left or right' unless %w[left right].include?(side)
        station = Float(anchor.fetch('station_mm', 0.0))
        gap = Float(anchor.fetch('gap_mm', 0.0))
        raise ArgumentError, 'Cabinet outside wall extent' if station < -0.1 || station+width > length+0.1
        face = face_offsets(wall)
        face_offset = side == 'left' ? face[1]+gap : face[0]-gap
        xaxis = side == 'left' ? [-ux,-uy,0.0] : [ux,uy,0.0]
        yaxis = side == 'left' ? [-nx,-ny,0.0] : [nx,ny,0.0]
        at = station + (side == 'left' ? width : 0.0)
        origin = [start[0]+ux*at+nx*face_offset-yaxis[0]*depth,
                  start[1]+uy*at+ny*face_offset-yaxis[1]*depth,
                  Float(wall.fetch('z', 0.0))+Float(anchor.fetch('mount_height',0.0))]
        { 'origin'=>origin, 'xaxis'=>xaxis, 'yaxis'=>yaxis, 'zaxis'=>[0.0,0.0,1.0],
          'wall_length'=>length }
      end

      def self.sync_binding(wall, raw, anchor)
        p = normalize(raw)
        a = anchor.dup
        if a.fetch('mode', 'fixed') == 'stretch'
          length = Math.hypot(wall['end'][0]-wall['start'][0],wall['end'][1]-wall['start'][1])
          p['width'] = (length - Float(a.fetch('station_mm')) - Float(a.fetch('end_gap_mm'))).round(4)
          p = normalize(p)
        elsif a.fetch('mode', 'fixed') != 'fixed'
          raise ArgumentError, 'Unknown binding mode'
        end
        [p, wall_frame(wall, a, p['width'], p['depth'])]
      end
    end
  end
end
