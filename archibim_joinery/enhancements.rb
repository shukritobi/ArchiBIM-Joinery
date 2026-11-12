# frozen_string_literal: true
# v0.2 parametric joinery additions; pure Ruby, dimensions in millimetres.
require_relative 'core'

module SSDigitalLab
  module ArchiBIMJoinery
    module Core
      APPLIANCES = %w[fridge_tall oven_tall microwave_tall].freeze
      HANDLE_STYLES = %w[none bar knob edge_45].freeze
      UPPER_STORAGE = %w[none open doors].freeze
      old_kinds = const_get(:KINDS)
      remove_const(:KINDS)
      const_set(:KINDS, (old_kinds + APPLIANCES).freeze)
      old_presets = const_get(:PRESETS)
      remove_const(:PRESETS)
      const_set(:PRESETS, old_presets.merge(
        'fridge_tall' => {'width'=>900,'height'=>2400,'depth'=>700,'toe_height'=>100,'top_thickness'=>0,'front'=>'open','shelves'=>0,'appliance_width'=>800,'appliance_height'=>1800,'appliance_bottom'=>100,'upper_storage'=>'doors'},
        'oven_tall' => {'width'=>600,'height'=>2400,'depth'=>600,'toe_height'=>100,'top_thickness'=>0,'front'=>'open','shelves'=>0,'appliance_width'=>560,'appliance_height'=>600,'appliance_bottom'=>950,'upper_storage'=>'doors'},
        'microwave_tall' => {'width'=>600,'height'=>2400,'depth'=>600,'toe_height'=>100,'top_thickness'=>0,'front'=>'open','shelves'=>0,'appliance_width'=>560,'appliance_height'=>450,'appliance_bottom'=>1300,'upper_storage'=>'doors'}
      ).freeze)

      module Enhancements
        def presets(kind)
          p = super
          p.merge('floor_finish_panels'=>true,'auto_doors'=>true,'max_door_width'=>600,
                  'handle_style'=>'none','handle_offset'=>50,'handle_cc'=>128,
                  'auto_wall_orient'=>true,'box_up'=>false,'ceiling_height'=>3000,
                  'appliance_width'=>0,'appliance_height'=>0,'appliance_bottom'=>0,
                  'appliance_side_clearance'=>4,'appliance_rear_clearance'=>50,
                  'upper_storage'=>'none')
        end

        def normalize(raw)
          p = super
          defaults = presets(p['kind'])
          %w[floor_finish_panels auto_doors auto_wall_orient box_up].each do |key|
            val = raw.fetch(key, defaults.fetch(key))
            p[key] = (val == true || val.to_s == 'true')
          end
          %w[max_door_width handle_offset handle_cc ceiling_height appliance_width appliance_height
             appliance_bottom appliance_side_clearance appliance_rear_clearance].each do |key|
            lo = key == 'max_door_width' ? 200 : 0
            p[key] = value(defaults.merge(raw), key, lo, 100_000)
          end
          p['handle_style'] = raw.fetch('handle_style', defaults['handle_style']).to_s
          raise ArgumentError, 'Unsupported handle style' unless HANDLE_STYLES.include?(p['handle_style'])
          p['upper_storage'] = raw.fetch('upper_storage', defaults['upper_storage']).to_s
          raise ArgumentError, 'Unsupported upper storage' unless UPPER_STORAGE.include?(p['upper_storage'])
          if p['auto_doors'] && %w[doors combo].include?(p['front'])
            opening = case_width(p)
            minimum = [(opening / (p['max_door_width']+p['door_gap'])).ceil, 1].max
            minimum += 1 while (opening-(minimum+1)*p['door_gap'])/minimum > p['max_door_width']
            p['door_count'] = [p['door_count'], minimum].max if p['kind'] == 'wardrobe' && p['door_count'] > minimum
            p['door_count'] = minimum unless p['kind'] == 'wardrobe' && p['door_count'] > minimum
          end
          if %w[doors combo].include?(p['front'])
            raise ArgumentError, 'More than 12 doors required; split into cabinet modules' if p['door_count'] > 12
            leaf = (case_width(p) - (p['door_count']+1)*p['door_gap']) / p['door_count'].to_f
            raise ArgumentError, 'Door leaf exceeds max door width' if leaf > p['max_door_width']+0.01
          end
          if APPLIANCES.include?(p['kind'])
            free_w = case_width(p) - 2*p['panel_thickness']
            needed = p['appliance_width'] + 2*p['appliance_side_clearance']
            raise ArgumentError, 'Appliance too wide for clear niche' if needed > free_w+0.01
            bottom = [p['appliance_bottom'], p['toe_height']+p['panel_thickness']].max
            top = bottom + p['appliance_height']
            raise ArgumentError, 'Appliance niche exceeds internal cabinet height' if top > p['height']-p['panel_thickness']*2
            raise ArgumentError, 'Appliance depth inadequate for rear clearance' if p['depth'] < p['appliance_rear_clearance']+100
          end
          if p['box_up'] && %w[wall tall fridge_tall oven_tall microwave_tall].include?(p['kind'])
            raise ArgumentError, 'Ceiling is below cabinet top' if p['ceiling_height'] < p['mount_height']+p['height']
          end
          p
        end

        def case_width(p)
          p['width']-p['filler_left']-p['filler_right']-
            p['panel_thickness']*((p['end_panel_left'] ? 1 : 0)+(p['end_panel_right'] ? 1 : 0))
        end

        def parts(raw)
          p = normalize(raw)
          result = APPLIANCES.include?(p['kind']) ? appliance_parts(p) : super(p)
          if p['floor_finish_panels']
            result.each do |part|
              next unless %w[filler finish].include?(part['role'])
              part['h'] += part['z']
              part['z'] = 0.0
            end
          end
          if p['box_up'] && %w[wall tall fridge_tall oven_tall microwave_tall].include?(p['kind'])
            extra = p['ceiling_height']-p['mount_height']-p['height']
            if extra > 0.01
              t=p['panel_thickness']; z=p['height']; w=p['width']; d=p['depth']
              add_part(result,'boxup-left','Left Ceiling Box-up',0,0,z,t,d,extra,'box_up',p)
              add_part(result,'boxup-right','Right Ceiling Box-up',w-t,0,z,t,d,extra,'box_up',p)
              add_part(result,'boxup-front','Front Ceiling Box-up',t,0,z,w-2*t,t,extra,'box_up',p)
              add_part(result,'boxup-back','Rear Ceiling Box-up',t,d-t,z,w-2*t,t,extra,'box_up',p)
            end
          end
          add_handles(result,p)
          result
        end

        def add_part(out,key,name,x,y,z,w,d,h,role,p,extra={})
          return unless w>0.01 && d>0.01 && h>0.01
          raise ArgumentError, "Non-finite #{name}" unless [x,y,z,w,d,h].all?(&:finite?)
          out << {'key'=>key,'name'=>name,'role'=>role,'material'=>p['material'],
                  'x'=>x.round(4),'y'=>y.round(4),'z'=>z.round(4),
                  'w'=>w.round(4),'d'=>d.round(4),'h'=>h.round(4)}.merge(extra)
        end

        def appliance_parts(p)
          out=[]; t=p['panel_thickness']; ft=p['front_thickness']; toe=p['toe_height']
          x0=p['filler_left']+(p['end_panel_left'] ? t : 0); cw=case_width(p)
          bottom=[p['appliance_bottom'],toe+t].max
          top=bottom+p['appliance_height']
          d=p['depth']; y=ft
          add_part(out,'side-left','Left Appliance Side',x0,y,toe,t,d-y,p['height']-toe,'carcass',p)
          add_part(out,'side-right','Right Appliance Side',x0+cw-t,y,toe,t,d-y,p['height']-toe,'carcass',p)
          add_part(out,'bottom','Appliance Unit Bottom',x0+t,y,toe,cw-2*t,d-y,t,'carcass',p)
          add_part(out,'top','Appliance Unit Top',x0+t,y,p['height']-t,cw-2*t,d-y,t,'carcass',p)
          add_part(out,'niche-bottom','Appliance Niche Base',x0+t,y,bottom-t,cw-2*t,d-y,t,'appliance_shelf',p)
          add_part(out,'niche-top','Appliance Niche Head',x0+t,y,top,cw-2*t,d-y,t,'appliance_shelf',p)
          add_part(out,'kick','Recessed Toe Kick',x0,p['toe_recess'],0,cw,t,toe,'toe_kick',p)
          # In the niche the back remains deliberately open. Rear airflow is manufacturer-specific.
          if p['upper_storage'] != 'none' && p['height']-t > top+t
            if p['upper_storage'] == 'doors'
              add_opening_doors(out,p,x0,cw,top+t,p['height']-t-(top+t),'upper')
            end
            add_part(out,'upper-back','Upper Storage Back',x0+t,d-p['back_thickness'],top+t,
                     cw-2*t,p['back_thickness'],p['height']-t-(top+t),'back',p) if p['back'] != 'none'
          end
          if p['kind'] != 'fridge_tall' && bottom>toe+2*t+100
            add_opening_doors(out,p,x0,cw,toe+t,bottom-t-(toe+t),'lower')
          end
          if p['filler_left']>0
            add_part(out,'filler-left','Left Filler',0,0,toe,p['filler_left'],t,p['height']-toe,'filler',p)
          end
          if p['filler_right']>0
            add_part(out,'filler-right','Right Filler',p['width']-p['filler_right'],0,toe,p['filler_right'],t,p['height']-toe,'filler',p)
          end
          if p['end_panel_left']
            add_part(out,'end-left','Left Finished Panel',p['filler_left'],0,toe,t,d,p['height']-toe,'finish',p)
          end
          if p['end_panel_right']
            add_part(out,'end-right','Right Finished Panel',p['width']-p['filler_right']-t,0,toe,t,d,p['height']-toe,'finish',p)
          end
          out
        end

        def add_opening_doors(out,p,x0,cw,z,height,prefix)
          gap=p['door_gap']; count=[(cw/(p['max_door_width']+gap)).ceil,1].max
          count+=1 while (cw-(count+1)*gap)/count > p['max_door_width']
          leaf=(cw-(count+1)*gap)/count
          count.times do |i|
            add_part(out,"#{prefix}-door-#{i+1}","#{prefix.capitalize} Door #{i+1}",
                     x0+gap+i*(leaf+gap),0,z+gap,leaf,p['front_thickness'],height-2*gap,
                     'door',p)
          end
        end

        def add_handles(result,p)
          doors=result.select { |r| r['role']=='door' }
          case p['handle_style']
          when 'edge_45'
            doors.each_with_index do |door,i|
              door['profile']='edge_45'
              door['profile_side']=i.even? ? 'right' : 'left'
              door['bevel_mm']=[p['front_thickness']*0.65,12].min.round(2)
            end
          when 'bar','knob'
            doors.each_with_index do |door,i|
              edge=i.even? ? 'right' : 'left'
              off=[p['handle_offset'],door['w']/2].min
              x=door['x']+(edge=='right' ? door['w']-off : off)
              z=door['z']+door['h']/2.0
              if p['handle_style']=='bar'
                length=[p['handle_cc']+24,door['h']-20].min
                add_part(result,"handle-#{door['key']}","Bar Handle #{door['name']}",x-6,-28,z-length/2,
                         12,12,length,'handle',p,{'material'=>'Brushed Steel'})
              else
                add_part(result,"handle-#{door['key']}","Knob #{door['name']}",x-12,-26,z-12,
                         24,22,24,'handle',p,{'material'=>'Brushed Steel'})
              end
            end
          end
          if p['handle_style']=='bar'
            result.select { |r| r['role']=='drawer_front' }.each do |dr|
              length=[p['handle_cc']+24,dr['w']-20].min
              add_part(result,"handle-#{dr['key']}","Drawer Bar #{dr['name']}",dr['x']+dr['w']/2-length/2,-28,
                       dr['z']+dr['h']/2-6,length,12,12,'handle',p,{'material'=>'Brushed Steel'})
            end
          end
        end

        def find_near_wall(walls,point,p,max_distance=350.0)
          px,py=point.map(&:to_f)
          best=nil
          walls.each do |wall|
            sx,sy=wall['start']; ex,ey=wall['end']; dx=ex-sx;dy=ey-sy
            length=Math.hypot(dx,dy); next if length < p['width']
            ux=dx/length;uy=dy/length
            station=(px-sx)*ux+(py-sy)*uy
            next if station < -max_distance || station>length+max_distance
            signed=-(px-sx)*uy+(py-sy)*ux
            a,b=face_offsets(wall)
            side=(signed-b).abs <= (signed-a).abs ? 'left' : 'right'
            distance=(signed-(side=='left' ? b : a)).abs
            next if distance>max_distance
            station=[[station,0].max,length-p['width']].min
            score=distance
            candidate={'wall'=>wall,'side'=>side,'station_mm'=>station,'score'=>score}
            best=candidate if !best || score<best['score']
          end
          best
        end
      end
      singleton_class.prepend(Enhancements)
    end
  end
end
