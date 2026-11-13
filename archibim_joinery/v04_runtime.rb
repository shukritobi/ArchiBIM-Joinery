# frozen_string_literal: true
# SketchUp geometry for v0.4 grip, mirror and basin proxies.
require_relative 'v04_features'

module SSDigitalLab
  module ArchiBIMJoinery
    module JoineryV04Runtime
      def build_geometry(group,data)
        super
        p=Core.normalize(data.fetch('params'))
        group.entities.grep(Sketchup::Group).each do |pg|
          raw=pg.get_attribute(DICT,'part_data')
          next unless raw
          part=JSON.parse(raw)
          profile=part['profile']
          next unless %w[center_groove edge_45_bottom edge_45_center basin_proxy].include?(profile) ||
                      part['shape']=='basin_proxy'
          if part['shape']=='basin_proxy'
            replace_basin_proxy(pg,part)
            next
          end
          w=part['w'].mm;d=part['d'].mm;h=part['h'].mm
          if profile=='edge_45_bottom'
            bevel=[part['bevel_mm'].to_f.mm,d*0.6,h*0.2].min
            poly=[[0,bevel,0],[0,d,0],[0,d,h],[0,0,h],[0,0,bevel]]
          else
            mid=if profile=='center_groove'
                  part['groove_mid'].to_f.mm
                else
                  (p['groove_center_height']-p['mount_height']-part['z']).mm
                end
            gh=(profile=='center_groove' ? part['groove_height'] : p['groove_height']).to_f.mm
            gd=(profile=='center_groove' ? part['groove_depth'] : p['groove_depth']).to_f.mm
            next unless mid>gh/2+10.mm && mid<h-gh/2-10.mm
            gd=[gd,d-3.mm].min
            poly=[[0,0,0],[0,d,0],[0,d,h],[0,0,h],
                  [0,0,mid+gh/2],[0,gd,mid+gh/2],
                  [0,gd,mid-gh/2],[0,0,mid-gh/2]]
          end
          replace_profile(pg,part,poly,w,X_AXIS)
        end
        group
      end

      # Explicitly labelled conceptual ceramic basin (not a fabrication cutout).
      # A 36-sided elliptical annulus and recessed well rather than a solid block.
      def replace_basin_proxy(pg,part)
        pg.entities.clear!
        w=part['w'].mm; d=part['d'].mm; h=part['h'].mm
        n=36
        ellipse=lambda do |sx,sy,z|
          (0...n).map do |i|
            angle=2*Math::PI*i/n
            [w/2+w*sx*0.5*Math.cos(angle),d/2+d*sy*0.5*Math.sin(angle),z]
          end
        end
        outer_top=ellipse.call(1.0,1.0,h)
        outer_bottom=ellipse.call(0.98,0.98,0)
        inner_top=ellipse.call(0.83,0.83,h)
        inner_bottom=ellipse.call(0.61,0.61,0)
        e=pg.entities
        4.times do |surface|
          a,b=case surface
              when 0 then [outer_bottom,outer_top]
              when 1 then [outer_top,inner_top]
              when 2 then [inner_top,inner_bottom]
              else [inner_bottom,outer_bottom]
              end
          n.times do |i|
            j=(i+1)%n
            # Triangles avoid warped quads on elliptical profiles.
            e.add_face(a[i],a[j],b[j])
            e.add_face(a[i],b[j],b[i])
          end
        end
        material=material_for(pg.model,part['material'])
        pg.entities.grep(Sketchup::Face).each{|f|f.material=material;f.back_material=material}
      end

      def material_for(model,name)
        mat=super
        case name.to_s
        when 'Mirror Glass'
          mat.color=Sketchup::Color.new(165,185,192)
        when 'Warm LED'
          mat.color=Sketchup::Color.new(255,223,153)
        when 'Ceramic White'
          mat.color=Sketchup::Color.new(246,246,241)
        end
        mat
      end
    end
    singleton_class.prepend(JoineryV04Runtime)
  end
end
