# frozen_string_literal: true
# v0.4 families: suspended basin/vanity, decorative wall panels, and mid-height grips.
require_relative 'layout'

module SSDigitalLab
  module ArchiBIMJoinery
    module Core
      previous_kinds=const_get(:KINDS)
      remove_const(:KINDS)
      const_set(:KINDS,(previous_kinds+%w[basin_vanity wall_panel]).freeze)
      previous_presets=const_get(:PRESETS)
      remove_const(:PRESETS)
      const_set(:PRESETS,previous_presets.merge(
        'basin_vanity'=>{
          'width'=>900,'height'=>550,'depth'=>500,'mount_height'=>450,
          'toe_height'=>0,'top_thickness'=>20,'front'=>'doors','back'=>'none','shelves'=>0
        },
        'wall_panel'=>{
          'width'=>1800,'height'=>2400,'depth'=>50,'toe_height'=>0,'top_thickness'=>0,
          'panel_thickness'=>10,'front'=>'open','back'=>'none','shelves'=>0
        }
      ).freeze)
      prior_handles=const_get(:HANDLE_STYLES)
      remove_const(:HANDLE_STYLES)
      const_set(:HANDLE_STYLES,(prior_handles+%w[center_groove]).freeze)

      module JoineryV04
        def presets(kind)
          p=super
          p.merge!({
            'groove_height'=>20,'groove_depth'=>10,'groove_center_height'=>900,
            'mirror_enabled'=>kind=='basin_vanity','mirror_width'=>800,
            'mirror_height'=>900,'mirror_bottom'=>1150,'mirror_thickness'=>20,
            'mirror_led'=>false,
            'basin_style'=>'countertop','basin_width'=>500,'basin_depth'=>350,
            'basin_height'=>45,
            'panel_led_bottom'=>kind=='wall_panel','panel_led_top'=>false,
            'panel_led_left'=>false,'panel_led_right'=>false,'panel_led_offset'=>15,
            'panel_led_width'=>12,'wall_panel_gaps'=>0
          })
          if kind=='basin_vanity'
            p['auto_wall_orient']=true
            p['handle_style']='knob'
            p['top_shadow_gap']=0
            p['end_panel_left']=true;p['end_panel_right']=true
            p['floor_finish_panels']=false
          elsif kind=='wall_panel'
            p['auto_wall_orient']=true
            p['handle_style']='none'
            p['top_shadow_gap']=0
          elsif kind=='tall' || kind=='wardrobe'
            # Standard wardrobe pulls are available; a mid-height 20x10 groove
            # is an explicit option, never an automatic top shadow gap.
            p['top_shadow_gap']=0
          elsif kind=='wall'
            p['top_shadow_gap']=0
          end
          p
        end

        def normalize(raw)
          p=super
          defaults=presets(p['kind'])
          %w[groove_height groove_depth groove_center_height
             mirror_width mirror_height mirror_bottom mirror_thickness
             basin_width basin_depth basin_height panel_led_offset panel_led_width].each do |key|
            p[key]=value(defaults.merge(raw),key,0,100_000)
          end
          p['wall_panel_gaps']=integer(defaults.merge(raw),'wall_panel_gaps',0,80)
          %w[mirror_enabled mirror_led panel_led_bottom panel_led_top panel_led_left panel_led_right].each do |key|
            x=raw.fetch(key,defaults[key]);p[key]=(x==true || x.to_s=='true')
          end
          p['basin_style']=raw.fetch('basin_style',defaults['basin_style']).to_s
          raise ArgumentError,'Unsupported basin style' unless %w[none countertop inset].include?(p['basin_style'])
          if p['handle_style']=='center_groove'
            raise ArgumentError,'Center groove requires a hinged front on a tall or wardrobe unit' unless
              %w[tall wardrobe corner_tall].include?(p['kind']) && %w[doors combo open].include?(p['front'])
            raise ArgumentError,'Groove must be 3mm to front thickness minus 3mm' unless
              p['groove_depth']>=3 && p['groove_depth']<=p['front_thickness']-3
            raise ArgumentError,'Groove height should be 5-60mm' unless p['groove_height'].between?(5,60)
          end
          if p['kind']=='basin_vanity'
            raise ArgumentError,'Mirror must fit above floor' if p['mirror_enabled'] && p['mirror_bottom']<0
            raise ArgumentError,'Basin must fit worktop' if p['basin_style']!='none' &&
              (p['basin_width']>p['width']-40 || p['basin_depth']>p['depth']-40)
            raise ArgumentError,'Basin vanity needs a worktop' if p['top_thickness']<10
          end
          if p['kind']=='wall_panel'
            raise ArgumentError,'Wall-panel LED offset exceeds panel envelope' if
              p['panel_led_offset']*2+p['panel_led_width']> [p['width'],p['height']].min
            raise ArgumentError,'Wall panel cannot have zero thickness' if p['depth']<15
            raise ArgumentError,'Too many slat gaps for panel width' if
              p['wall_panel_gaps']>0 && p['width']/(p['wall_panel_gaps']+1.0)<30
          end
          p
        end

        def parts(raw)
          p=normalize(raw)
          return wall_panel_parts(p) if p['kind']=='wall_panel'
          result=super(p)
          if p['kind']=='basin_vanity'
            vanity_fittings(result,p)
          elsif %w[tall wardrobe corner_tall].include?(p['kind']) && p['handle_style']=='center_groove'
            result.select{|part|part['role']=='door'}.each do |door|
              mid=p['groove_center_height']-p['mount_height']-door['z']
              next unless mid>p['groove_height']/2+20 && mid<door['h']-p['groove_height']/2-20
              door['profile']='center_groove'
              door['groove_mid']=mid.round(4)
              door['groove_height']=p['groove_height']
              door['groove_depth']=p['groove_depth']
            end
          end
          result
        end

        def vanity_fittings(result,p)
          if p['basin_style']!='none'
            w=[p['basin_width'],p['width']-40].min; d=[p['basin_depth'],p['depth']-40].min
            z=p['basin_style']=='inset' ? p['height']-12 : p['height']
            add_part(result,'basin','Basin (Conceptual)',(p['width']-w)/2,25,z,
                     w,d,p['basin_style']=='inset' ? 12 : p['basin_height'],
                     'basin',p,{'material'=>'Ceramic White','shape'=>'basin_proxy'})
          end
          return unless p['mirror_enabled']
          mw=p['mirror_width']; mh=p['mirror_height']; mt=p['mirror_thickness']
          x=(p['width']-mw)/2.0
          z=p['mirror_bottom']-p['mount_height']
          add_part(result,'vanity-mirror','Wall Mirror',x,p['depth']-mt,z,mw,mt,mh,
                   'mirror',p,{'material'=>'Mirror Glass'})
          if p['mirror_led']
            # Conceptual wall mirror lighting bar, individually tagged.
            add_part(result,'mirror-led','Mirror Back LED',x+15,p['depth']-mt-5,z+10,
                     mw-30,8,8,'led',p,{'material'=>'Warm LED'})
          end
          result
        end

        def wall_panel_parts(p)
          out=[]; w=p['width'];h=p['height']; d=p['depth'];n=p['wall_panel_gaps']
          if n==0
            add_part(out,'panel-1','Wall Cladding Panel',0,0,0,w,d,h,'wall_panel',p)
          else
            gap=3.0
            segment=(w-gap*n)/(n+1.0)
            (n+1).times do |i|
              add_part(out,"panel-#{i+1}","Wall Panel #{i+1}",
                       i*(segment+gap),0,0,segment,d,h,'wall_panel',p)
            end
          end
          offset=p['panel_led_offset'];led=p['panel_led_width']
          if p['panel_led_bottom']
            add_part(out,'panel-led-bottom','Lower Panel LED Diffuser',offset,-3,offset,
                     w-2*offset,8,led,'led',p,{'material'=>'Warm LED'})
          end
          if p['panel_led_top']
            add_part(out,'panel-led-top','Upper Panel LED Diffuser',offset,-3,h-offset-led,
                     w-2*offset,8,led,'led',p,{'material'=>'Warm LED'})
          end
          if p['panel_led_left']
            add_part(out,'panel-led-left','Left Panel LED Diffuser',offset,-3,offset,
                     led,8,h-2*offset,'led',p,{'material'=>'Warm LED'})
          end
          if p['panel_led_right']
            add_part(out,'panel-led-right','Right Panel LED Diffuser',w-offset-led,-3,offset,
                     led,8,h-2*offset,'led',p,{'material'=>'Warm LED'})
          end
          out
        end
      end
      singleton_class.prepend(JoineryV04)
    end
  end
end
