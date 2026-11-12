# frozen_string_literal: true
# SketchUp-specific integration. Loaded after main.rb has registered the extension UI.
require_relative 'drafting'

module SSDigitalLab
  module ArchiBIMJoinery
    module RuntimeExtensions
      def build_geometry(group,data)
        super
        group.entities.grep(Sketchup::Group).each do |part_group|
          raw=part_group.get_attribute(DICT,'part_data')
          next unless raw
          part=JSON.parse(raw)
          next unless part['profile']=='edge_45'
          w=part['w'].mm; d=part['d'].mm; h=part['h'].mm
          bevel=[part['bevel_mm'].mm,d*0.8,w*0.25].min
          polygon = if part['profile_side']=='left'
                      [[0,bevel,0],[bevel,0,0],[w,0,0],[w,d,0],[0,d,0]]
                    else
                      [[0,0,0],[w-bevel,0,0],[w,bevel,0],[w,d,0],[0,d,0]]
                    end
          part_group.entities.clear!
          face=part_group.entities.add_face(polygon)
          raise "45 degree door profile failed: #{part['key']}" unless face
          face.reverse! if face.normal.z<0
          face.pushpull(h)
          mat=material_for(group.model,part['material'])
          part_group.entities.grep(Sketchup::Face).each { |f| f.material=mat; f.back_material=mat }
        end
        add_elevation_symbols(group,data)
        group
      end

      def add_elevation_symbols(group,data)
        p=Core.normalize(data['params'])
        lines=Drafting.opening_segments(p)
        return if lines.empty?
        model=group.model
        layer=model.layers['ABJ | 2D Elevation Openings'] || model.layers.add('ABJ | 2D Elevation Openings')
        if model.respond_to?(:line_styles)
          style=model.line_styles['Dash'] || model.line_styles['Short Dash']
          layer.line_style=style if style && layer.respond_to?(:line_style=)
        end
        # Disabled initially so symbolic lines do not obstruct perspective and render views.
        # Turn the tag ON in an orthographic front-elevation scene / LayOut viewport.
        layer.visible=false if layer.visible? && !model.get_attribute(DICT,'show_elevation_openings',false)
        symbols=group.entities.add_group
        symbols.name='ABJ | 2D Elevation Opening Symbols'
        symbols.layer=layer
        lines.each do |x1,z1,x2,z2,_|
          symbols.entities.add_line([x1.mm,-1.mm,z1.mm],[x2.mm,-1.mm,z2.mm])
        end
        symbols.set_attribute(DICT,'drawing_kind','elevation_openings')
      end

      def create(params,point)
        group=super
        config=Core.normalize(params)
        return group unless config['auto_wall_orient']
        walls=bim_walls(group.model).map(&:last)
        return group if walls.empty?
        candidate=Core.find_near_wall(walls,[point.x.to_mm,point.y.to_mm],config)
        return group unless candidate
        wall=candidate['wall']
        anchor={'wall_id'=>wall['id'],'side'=>candidate['side'],'mode'=>'fixed',
                'station_mm'=>candidate['station_mm'],'end_gap_mm'=>0.0,'gap_mm'=>0.0,
                'mount_height'=>config['mount_height'],'wall_signature'=>wall_signature(wall)}
        anchor['end_gap_mm']=Math.hypot(wall['end'][0]-wall['start'][0],wall['end'][1]-wall['start'][1])-
                             anchor['station_mm']-config['width']
        fitted,frame=Core.sync_binding(wall,config,anchor)
        model=group.model
        model.start_operation('ArchiBIM Joinery: Auto-orient to wall',true)
        begin
          data=data_for(group)
          data['anchor']=anchor
          data['params']=fitted
          group.transformation=to_transform(frame)
          build_geometry(group,data)
          model.commit_operation
          log('auto_wall_bound',wall_id:wall['id'],cabinet_id:data['id'],side:anchor['side'],distance_mm:candidate['score'])
          refresh
        rescue StandardError => e
          model.abort_operation
          log('auto_wall_error',error:e.message)
        end
        group
      end

      def refresh_scaled_selected
        group=selected_cabinet
        raise 'Select a Joinery cabinet first' unless group
        tr=group.transformation
        axes=[tr.xaxis,tr.yaxis,tr.zaxis]
        lengths=axes.map(&:length)
        raise 'Cannot refresh zero, negative or degenerate scale' if lengths.any? { |s| !s.finite? || s<0.001 }
        unit=axes.map(&:normalize)
        ortho=[unit[0].dot(unit[1]),unit[0].dot(unit[2]),unit[1].dot(unit[2])]
        raise 'Shear transform is unsupported; use the native Scale tool without skewing' if ortho.any? { |d| d.abs>0.01 }
        raise 'Mirrored transforms are unsupported' unless unit[0].cross(unit[1]).dot(unit[2])>0.99
        data=data_for(group)
        p=data['params'].dup
        %w[width depth height].zip(lengths).each { |k,f| p[k] = (p[k].to_f*f).round(3) }
        p=Core.normalize(p) # validates thickness and appliance clearances BEFORE clearing geometry
        model=group.model
        model.start_operation('ArchiBIM Joinery: Refresh native Scale',true)
        begin
          frame=Geom::Transformation.axes(tr.origin,*unit)
          if data['anchor']
            found=find_wall(model,data['anchor']['wall_id'])
            if found
              data['anchor']['mode']='fixed' # user-scaled width wins over stretch mode
              data['anchor']['mount_height']=p['mount_height']
              p,wall_frame=Core.sync_binding(found[1],p,data['anchor'])
              frame=to_transform(wall_frame)
              data['anchor']['end_gap_mm']=wall_frame['wall_length']-data['anchor']['station_mm']-p['width']
              data['anchor']['wall_signature']=wall_signature(found[1])
            end
          end
          data['params']=p
          group.transformation=frame
          build_geometry(group,data)
          model.commit_operation
          log('scale_refreshed',cabinet_id:data['id'],scale:lengths,dimensions:p.values_at('width','depth','height'))
          refresh
        rescue StandardError
          model.abort_operation
          raise
        end
        p
      end

      def export_selected_dxf
        group=selected_cabinet
        raise 'Select a Joinery cabinet first' unless group
        data=data_for(group)
        basename="ABJ_#{data['id'][0,8]}_elevation_plan.dxf"
        path=UI.savepanel('Export Joinery 2D Elevation and Plan DXF','',basename)
        return unless path
        File.binwrite(path,Drafting.dxf(data['params'],data['id']))
        log('dxf_export',cabinet_id:data['id'],file:path)
        UI.messagebox("2D DXF exported: #{path}\nUnit: millimetres; front elevation and plan; dashed opening lines.")
        path
      end

      def export_all_dxf
        entries=all_cabinets
        raise 'No Joinery cabinets in this model' if entries.empty?
        dir=UI.select_directory(title:'Choose folder for one DXF per cabinet')
        return unless dir
        entries.each do |_group,data|
          name=data['params']['name'].gsub(/[^a-zA-Z0-9_-]+/,'_')[0,45]
          filename="ABJ_#{name}_#{data['id'][0,8]}.dxf"
          File.binwrite(File.join(dir,filename),Drafting.dxf(data['params'],data['id']))
        end
        log('dxf_batch_export',count:entries.size,folder:dir)
        UI.messagebox("Exported #{entries.size} cabinet DXF drawings to #{dir}")
      end

      def export_ai_json
        entries=all_cabinets
        raise 'No Joinery cabinets in this model' if entries.empty?
        path=UI.savepanel('Export Joinery structured data for MCP / AI','', 'ArchiBIM_Joinery_Cabinets.json')
        return unless path
        data={'schema'=>'archibim-joinery/v1','units'=>'mm','generated_at'=>Time.now.utc.iso8601,
              'cabinets'=>entries.map do |_g,c|
                p=Core.normalize(c['params'])
                {'id'=>c['id'],'name'=>p['name'],'kind'=>p['kind'],'params'=>p,
                 'host'=>c['anchor'],'parts'=>Core.parts(p),
                 'elevation_openings'=>Drafting.opening_segments(p),
                 'plan_lines'=>Drafting.plan_segments(p)}
              end}
        File.write(path,JSON.pretty_generate(data))
        log('ai_json_export',count:entries.size,file:path)
        UI.messagebox("Structured cabinet data exported: #{path}\nRead-only exchange format, not a live MCP server.")
      end
    end

    singleton_class.prepend(RuntimeExtensions)
    require 'time'
    # Add menu commands independent of the existing HtmlDialog callbacks.
    unless defined?(@extra_menus_registered) && @extra_menus_registered
      submenu=UI.menu('Extensions').add_submenu('ArchiBIM Joinery: Documentation')
      submenu.add_item('Refresh Selected After Native Scale') { refresh_scaled_selected }
      submenu.add_item('Export Selected Elevation + Plan DXF') { export_selected_dxf }
      submenu.add_item('Export All Cabinet Drawings DXF') { export_all_dxf }
      submenu.add_item('Export Structured Cabinet JSON (AI/MCP)') { export_ai_json }
      @extra_menus_registered=true
    end
  end
end
