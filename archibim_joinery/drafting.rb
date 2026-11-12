# frozen_string_literal: true
# Standalone ASCII DXF R12 2D linework, in millimetres; no gems required.
require_relative 'enhancements'

module SSDigitalLab
  module ArchiBIMJoinery
    module Drafting
      extend self
      C = Core
      LAYERS = %w[ABJ_ELEVATION ABJ_ELEVATION_OPENING ABJ_ELEVATION_DRAWERS ABJ_PLAN ABJ_PLAN_INTERNAL ABJ_PLAN_DRAWERS ABJ_LABEL].freeze

      def rectangle(x1,y1,x2,y2,layer)
        [[x1,y1,x2,y1,layer],[x2,y1,x2,y2,layer],
         [x2,y2,x1,y2,layer],[x1,y2,x1,y1,layer]]
      end

      def elevation_segments(raw)
        p=C.normalize(raw)
        segments=rectangle(0,0,p['width'],p['height'], 'ABJ_ELEVATION')
        C.parts(p).each do |part|
          next unless %w[door drawer_front filler finish box_up skirting].include?(part['role'])
          x=part['x']; z=part['z']; w=part['w']; h=part['h']
          segments.concat(rectangle(x,z,x+w,z+h,'ABJ_ELEVATION'))
        end
        segments.concat(opening_segments(p))
        C.parts(p).select { |part| part['role']=='drawer_front' }.each do |dr|
          segments << [dr['x'],dr['z']+dr['h'],dr['x']+dr['w'],dr['z']+dr['h'],'ABJ_ELEVATION_DRAWERS']
        end
        segments
      end

      def opening_segments(raw)
        p=C.normalize(raw)
        segments=[]
        C.parts(p).select { |part| part['role']=='door' }.each_with_index do |door,index|
          x=door['x'];z=door['z'];w=door['w'];h=door['h'];
          # Conventional dashed elevation chevron: hinge at the pair of corners.
          hinge_x=index.even? ? x : x+w
          free_x=index.even? ? x+w : x
          segments << [hinge_x,z,free_x,z+h/2,'ABJ_ELEVATION_OPENING']
          segments << [hinge_x,z+h,free_x,z+h/2,'ABJ_ELEVATION_OPENING']
        end
        # Drawer projection: dashed pull/opening chevron, similar to the
        # door symbolic linework used by ArchiBIM. Kept independent of solids.
        C.parts(p).select { |part| part['role']=='drawer_front' }.each do |dr|
          left=dr['x']+dr['w']*0.08
          right=dr['x']+dr['w']*0.92
          peak=dr['x']+dr['w']/2
          upper=dr['z']+dr['h']*0.82
          lower=dr['z']+dr['h']*0.24
          segments << [left,upper,peak,lower,'ABJ_ELEVATION_OPENING']
          segments << [right,upper,peak,lower,'ABJ_ELEVATION_OPENING']
        end
        segments
      end

      def plan_segments(raw)
        p=C.normalize(raw)
        result=rectangle(0,0,p['width'],p['depth'],'ABJ_PLAN')
        C.parts(p).select { |part| %w[filler finish carcass].include?(part['role']) }.each do |part|
          # Show main side panels and side fillers in plan, not horizontal shelves.
          next unless part['key'].start_with?('side-','end-','filler-')
          result.concat(rectangle(part['x'],part['y'],part['x']+part['w'],part['y']+part['d'], 'ABJ_PLAN_INTERNAL'))
        end
        # One representative drawer tray in plan; all other tiers share the footprint.
        tray=C.parts(p).select { |part| %w[drawer_box drawer_runner].include?(part['role']) }
        representative=tray.map { |item| item['key'].sub(/-\d+\z/,'') }.uniq
        representative.each do |prefix|
          part=tray.find { |item| item['key'].sub(/-\d+\z/,'')==prefix }
          next unless part
          result.concat(rectangle(part['x'],part['y'],part['x']+part['w'],part['y']+part['d'],'ABJ_PLAN_DRAWERS'))
        end
        result
      end

      def fmt(n)
        ('%.4f' % n.to_f).sub(/0+\z/,'').sub(/\.\z/,'')
      end

      def pairs(*values)
        values.flatten.map(&:to_s).join("\n")+"\n"
      end

      def line(a,b,c,d,layer)
        pairs(0,'LINE',8,layer,10,fmt(a),20,fmt(b),30,0,11,fmt(c),21,fmt(d),31,0)
      end

      def text(x,y,message,height=35)
        pairs(0,'TEXT',8,'ABJ_LABEL',10,fmt(x),20,fmt(y),30,0,40,height,1,message)
      end

      def dxf(raw,id='')
        p=C.normalize(raw)
        # Separate views side by side: elevation at origin, plan offset to the right.
        offset=p['width']+200
        doc=+''
        doc << pairs(0,'SECTION',2,'HEADER',9,'$ACADVER',1,'AC1009',9,'$MEASUREMENT',70,1,0,'ENDSEC')
        doc << pairs(0,'SECTION',2,'TABLES',0,'TABLE',2,'LTYPE',70,2)
        doc << pairs(0,'LTYPE',2,'CONTINUOUS',70,0,3,'Solid line',72,65,73,0,40,0)
        doc << pairs(0,'LTYPE',2,'DASHED',70,0,3,'Dashed line',72,65,73,2,40,12,49,8,49,-4)
        doc << pairs(0,'ENDTAB',0,'TABLE',2,'LAYER',70,LAYERS.size)
        LAYERS.each do |layer|
          doc << pairs(0,'LAYER',2,layer,70,0,62,7,6,(layer=='ABJ_ELEVATION_OPENING' ? 'DASHED' : 'CONTINUOUS'))
        end
        doc << pairs(0,'ENDTAB',0,'ENDSEC',0,'SECTION',2,'ENTITIES')
        elevation_segments(p).each { |x1,y1,x2,y2,layer| doc << line(x1,y1,x2,y2,layer) }
        plan_segments(p).each { |x1,y1,x2,y2,layer| doc << line(x1+offset,y1,x2+offset,y2,layer) }
        label=p['name'].gsub(/[\r\n]/,' ')[0,80]
        doc << text(0,-90,"ELEVATION | #{label} | #{fmt(p['width'])} x #{fmt(p['height'])} mm")
        doc << text(offset,-90,"PLAN | #{fmt(p['width'])} x #{fmt(p['depth'])} mm")
        doc << text(0,-145,"ABJ: #{id.to_s[0,36]} | SCHEMATIC - VERIFY INSTALLATION",24)
        doc << pairs(0,'ENDSEC',0,'EOF')
        doc
      end
    end
  end
end
