# frozen_string_literal: true
# SketchUp-specific integration. Loaded after main.rb has registered the extension UI.
require_relative 'drafting'
require_relative 'scale_math'

module SSDigitalLab
  module ArchiBIMJoinery
    module RuntimeExtensions
      def build_geometry(group,data)
        super
        group.entities.grep(Sketchup::Group).each do |part_group|
          raw=part_group.get_attribute(DICT,'part_data')
          next unless raw
          part=JSON.parse(raw)
          if part['profile']=='edge_45_top'
            # A continuous finger-access 45-degree grip behind the top front edge.
            w=part['w'].mm; d=part['d'].mm; h=part['h'].mm
            bevel=[part['bevel_mm'].mm,d*0.75,h*0.2].min
            points=[[0,0,0],[0,d,0],[0,d,h-bevel],[0,d-bevel,h],[0,0,h]]
            replace_profile(part_group,part,points,w,X_AXIS)
          elsif part['shape']=='cylinder'
            replace_round_handle(part_group,part)
          end
        end
        add_elevation_symbols(group,data)
        add_2d_drawing_groups(group,data)
        group
      end

      def replace_profile(pg,part,points,distance,direction)
        pg.entities.clear!
        face=pg.entities.add_face(points)
        raise "Unable to form profile #{part['key']}" unless face
        face.reverse! if face.normal.dot(direction)<0
        face.pushpull(distance)
        mat=material_for(pg.model,part['material'])
        pg.entities.grep(Sketchup::Face).each { |f| f.material=mat; f.back_material=mat }
      end

      # High-segment circular hardware: doors vertical, drawers horizontal.
      def replace_round_handle(pg,part)
        w=part['w'].mm; d=part['d'].mm; h=part['h'].mm
        label=part['name']
        axis=if label.include?('Post') || label.include?('Knob')
               :y
             elsif label.include?('Drawer Bar')
               :x
             else
               :z
             end
        case axis
        when :y
          radius=[w,h].min*0.5
          cx=w/2.0; cz=h/2.0
          points=(0...40).map { |i| t=2*Math::PI*i/40; [cx+radius*Math.cos(t),0,cz+radius*Math.sin(t)] }
          distance=d; direction=Y_AXIS
        when :x
          radius=[d,h].min*0.5
          cy=d/2.0; cz=h/2.0
          points=(0...32).map { |i| t=2*Math::PI*i/32; [0,cy+radius*Math.cos(t),cz+radius*Math.sin(t)] }
          distance=w; direction=X_AXIS
        else
          radius=[w,d].min*0.5
          cx=w/2.0; cy=d/2.0
          points=(0...32).map { |i| t=2*Math::PI*i/32; [cx+radius*Math.cos(t),cy+radius*Math.sin(t),0] }
          distance=h; direction=Z_AXIS
        end
        replace_profile(pg,part,points,distance,direction)
      end

      # Native per-cabinet linework that can be switched on in orthographic
      # SketchUp scenes (and then displayed via those scenes in LayOut).
      # Groups use the cabinet's local coordinate system so they follow its host.
      def add_2d_drawing_groups(group,data)
        p=Core.normalize(data['params'])
        model=group.model
        drawings=[
          ['ABJ | 2D Elevation Linework','elevation',
           Drafting.elevation_segments(p).reject { |v| v[4]=='ABJ_ELEVATION_OPENING' }],
          ['ABJ | 2D Plan Linework','plan',Drafting.plan_segments(p)]
        ]
        box_top=p['box_up'] ? [p['height'],p['ceiling_height']-p['mount_height']].max : p['height']
        drawings.each do |tag_name,kind,segments|
          next if segments.empty?
          layer=model.layers[tag_name]
          unless layer
            layer=model.layers.add(tag_name)
            layer.visible=false unless model.get_attribute(DICT,'show_2d_drawings',false)
          end
          organize_joinery_tag(model, layer)
          drawing=group.entities.add_group
          drawing.name="ABJ | 2D #{kind.capitalize} (Layout)"
          drawing.layer=layer
          drawing.set_attribute(DICT,'drawing_kind',kind)
          segments.each do |x1,v1,x2,v2,_line_layer|
            a,b=if kind=='plan'
                  [[x1.mm,v1.mm,(box_top+2).mm],[x2.mm,v2.mm,(box_top+2).mm]]
                else
                  [[x1.mm,-3.mm,v1.mm],[x2.mm,-3.mm,v2.mm]]
                end
            drawing.entities.add_line(a,b)
          end
        end
      end

      def add_elevation_symbols(group,data)
        p=Core.normalize(data['params'])
        lines=Drafting.opening_segments(p)
        return if lines.empty?
        model=group.model
        layer=model.layers['ABJ | 2D Elevation Openings']
        new_layer=layer.nil?
        layer ||= model.layers.add('ABJ | 2D Elevation Openings')
        organize_joinery_tag(model, layer)
        if model.respond_to?(:line_styles)
          style=model.line_styles['Dash'] || model.line_styles['Short Dash']
          layer.line_style=style if style && layer.respond_to?(:line_style=)
        end
        # Disabled initially so symbolic lines do not obstruct perspective and render views.
        # Turn the tag ON in an orthographic front-elevation scene / LayOut viewport.
        layer.visible=false if new_layer && !model.get_attribute(DICT,'show_elevation_openings',false)
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

      def edit_selected(params)
        group=selected_cabinet
        if group
          tr=group.transformation
          factors, = ScaleMath.decompose(tr)
          if ScaleMath.changed?(factors)
            raise 'Native scaling is still applied to this cabinet. Use Refresh Native Scale or Resize to W / D / H before Update Selected.'
          end
        end
        super(params)
      end

      # Read final root group transform and rebuild a cabinet without
      # scaling panel material thickness. Call only after completing Scale.
      def refresh_scaled_selected(transparent: false)
        group=selected_cabinet
        raise 'Select a generated Joinery cabinet (the outer group)' unless group
        tr=group.transformation
        lengths, unit = ScaleMath.decompose(tr)
        unless ScaleMath.changed?(lengths)
          msg='No group scaling detected. Finish the native Scale tool (click or Enter), select the OUTER cabinet group, then Refresh. Alternatively edit Width/Depth/Height at the top and press Resize.'
          log('scale_no_transform',id:data_for(group)['id'],factors:lengths)
          raise msg
        end
        data=data_for(group)
        p=ScaleMath.apply_dimensions(data['params'],lengths)
        frame=Geom::Transformation.axes(tr.origin,*unit)
        commit_parametric_resize(group,data,p,frame,source:'native_scale',factors:lengths,transparent:transparent)
      end

      # Numeric fallback for Scale tool transforms unavailable at selection root.
      def resize_selected_dimensions(raw)
        group=selected_cabinet
        raise 'Select a generated Joinery cabinet (outer group)' unless group
        data=data_for(group)
        values=raw.is_a?(String) ? JSON.parse(raw) : raw
        keys=%w[width depth height]
        new_dims=keys.to_h { |key| [key,values.fetch(key)] }
        p=Core.normalize(data['params'].merge(new_dims))
        tr=group.transformation
        _lengths, normalized_axes=ScaleMath.decompose(tr)
        frame=Geom::Transformation.axes(tr.origin,*normalized_axes)
        commit_parametric_resize(group,data,p,frame,source:'numeric_resize')
      end

      def commit_parametric_resize(group,data,p,frame,source:,factors:nil,transparent:false)
        model=group.model
        # Validate wall fit before committing a model mutation.
        if data['anchor']
          found=find_wall(model,data['anchor']['wall_id'])
          if found
            anchor=data['anchor'].dup
            anchor['mode']='fixed'
            anchor['mount_height']=p['mount_height']
            p,wall_frame=Core.sync_binding(found[1],p,anchor)
            frame=to_transform(wall_frame)
            anchor['end_gap_mm']=wall_frame['wall_length']-anchor['station_mm']-p['width']
            anchor['wall_signature']=wall_signature(found[1])
            data['anchor']=anchor
          end
        end
        model.start_operation('ArchiBIM Joinery: Parametric resize',true,false,transparent)
        begin
          previous=data['params'].values_at('width','depth','height')
          data['params']=p
          group.transformation=frame
          build_geometry(group,data)
          model.selection.clear
          model.selection.add(group)
          model.commit_operation
          log('parametric_resize',id:data['id'],source:source,previous:previous,
              new_dimensions:p.values_at('width','depth','height'),factors:factors)
          refresh
          p
        rescue StandardError=>e
          model.abort_operation
          log('resize_error',id:data['id'],source:source,error:e.message)
          raise
        end
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

    # SketchUp documents onToolStateChanged as nonstandard and coalesced.
    # Wait until the active tool changes away from Scale (21236), then refresh.
    # The explicit Refresh Selected menu remains a fallback when Scale stays active.
    class NativeScaleWatcher < Sketchup::ToolsObserver
      SCALE_TOOL_ID = 21236

      def onActiveToolChanged(_tools, _tool_name, tool_id)
        if tool_id == SCALE_TOOL_ID
          @was_scale = true
          return
        end
        return unless @was_scale
        @was_scale = false
        UI.start_timer(0.1, false) { refresh_after_scale }
      end

      def refresh_after_scale
        joinery = SSDigitalLab::ArchiBIMJoinery
        # Selection-changing rebuild is only safe for exactly one cabinet.
        # Never discard other selected objects during native multi-Scale.
        selected_cabinets = Sketchup.active_model.selection.to_a.select { |e| joinery.data_for(e) }
        if selected_cabinets.length != 1
          joinery.log('native_scale_multi_selection_skipped',
            selected_cabinets: selected_cabinets.length) if selected_cabinets.length > 1
          return
        end
        selected = selected_cabinets.first
        return unless selected && selected.valid?
        factors, = joinery::ScaleMath.decompose(selected.transformation)
        return unless joinery::ScaleMath.changed?(factors)
        joinery.refresh_scaled_selected
      rescue StandardError => e
        SSDigitalLab::ArchiBIMJoinery.log('native_scale_auto_error', error: e.message,
          backtrace: e.backtrace&.first(8))
      end
    end

    module NativeScaleObserverInstall
      def watch(model)
        super
        @native_scale_watchers ||= {}
        key=model.object_id
        return if @native_scale_watchers.key?(key)
        observer=NativeScaleWatcher.new
        model.tools.add_observer(observer)
        @native_scale_watchers[key]=observer
      end
    end

    singleton_class.prepend(RuntimeExtensions)
    singleton_class.prepend(NativeScaleObserverInstall)
    watch(Sketchup.active_model)
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
