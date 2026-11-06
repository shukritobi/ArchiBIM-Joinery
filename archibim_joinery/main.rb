# frozen_string_literal: true
require 'sketchup.rb'
require 'json'
require 'csv'
require 'securerandom'
require_relative 'core'

module SSDigitalLab
  module ArchiBIMJoinery
    extend self
    VERSION = '0.1.0'
    DICT = 'SSDigitalLab_ArchiBIM_Joinery'
    ARCH_DICT = 'SSDigitalLab_ArchiBIM'
    @dialog = nil
    @sync_queued = false
    @sync_running = false
    @auto_sync = true
    @watchers = {}
    @log = []

    def log(event, fields={})
      item = { at: Time.now.strftime('%Y-%m-%d %H:%M:%S'), event: event, fields: fields }
      @log << item
      @log.shift while @log.size > 300
      puts("[ArchiBIM Joinery] #{JSON.generate(item)}")
      item
    end

    def data_for(entity)
      return nil unless entity && entity.valid? && entity.is_a?(Sketchup::Group)
      raw = entity.get_attribute(DICT, 'data')
      return nil if raw.nil?
      data = JSON.parse(raw)
      data.is_a?(Hash) && data['schema'].to_i == Core::SCHEMA && data['params'].is_a?(Hash) ? data : nil
    rescue JSON::ParserError
      nil
    end

    def selected_cabinet
      Sketchup.active_model.selection.find { |e| data_for(e) }
    end

    def all_cabinets(model=Sketchup.active_model)
      model.entities.grep(Sketchup::Group).filter_map do |group|
        data = data_for(group)
        [group,data] if data
      end
    end

    def bim_walls(model=Sketchup.active_model)
      model.entities.grep(Sketchup::Group).filter_map do |g|
        begin
          raw = g.get_attribute(ARCH_DICT, 'data')
          next unless raw
          h = JSON.parse(raw)
          next unless h['kind'] == 'wall' && h['id']
          t = g.transformation
          a = ORIGIN.transform(t)
          b = Geom::Point3d.new(h['length'].to_f.mm, 0, 0).transform(t)
          desc = { 'id'=>h['id'], 'name'=>h['name'], 'start'=>[a.x.to_mm,a.y.to_mm],
                   'end'=>[b.x.to_mm,b.y.to_mm], 'z'=>a.z.to_mm,
                   'thickness'=>h['thickness'].to_f, 'alignment'=>h.fetch('alignment','center'),
                   'level_id'=>h['level_id'] }
          [g, desc]
        rescue StandardError => e
          log('invalid_wall', error: e.message)
          nil
        end
      end
    end

    def find_wall(model, uuid)
      bim_walls(model).find { |_,desc| desc['id'] == uuid }
    end

    def selected_wall
      Sketchup.active_model.selection.find do |e|
        e.is_a?(Sketchup::Group) && begin
          h = JSON.parse(e.get_attribute(ARCH_DICT,'data').to_s)
          h['kind'] == 'wall'
        rescue JSON::ParserError
          false
        end
      end
    end

    def material_for(model, name)
      short = name.to_s.strip[0,80]
      short = 'White Melamine' if short.empty?
      label = "ABJ | #{short}"
      material = model.materials[label] || model.materials.add(label)
      if short.downcase.include?('wood') || short.downcase.include?('oak')
        material.color = Sketchup::Color.new(188, 156, 117)
      elsif short.downcase.include?('black')
        material.color = Sketchup::Color.new(60, 64, 70)
      elsif short.downcase.include?('grey') || short.downcase.include?('gray')
        material.color = Sketchup::Color.new(170, 174, 178)
      else
        material.color = Sketchup::Color.new(229, 228, 223)
      end
      material
    end

    def tag_for(model, role)
      name = "ABJ | #{role.to_s.split('_').map(&:capitalize).join(' ')}"
      model.layers[name] || model.layers.add(name)
    end

    def build_geometry(group, data)
      params = Core.normalize(data.fetch('params'))
      parts = Core.parts(params) # validate entire BOM before destroying old geometry
      model = group.model
      group.entities.clear!
      parts.each do |part|
        pg = group.entities.add_group
        pg.name = part['name']
        pg.set_attribute(DICT, 'part_key', "#{data['id']}:#{part['key']}")
        pg.set_attribute(DICT, 'part_data', JSON.generate(part))
        w=part['w'].mm; d=part['d'].mm; h=part['h'].mm
        face = pg.entities.add_face([0,0,0], [w,0,0], [w,d,0], [0,d,0])
        raise "Cannot build #{part['name']}" unless face
        face.reverse! if face.normal.z < 0 # positive normal extrudes upwards
        face.pushpull(h)
        mat = material_for(model, part['material'])
        pg.material = mat
        pg.entities.grep(Sketchup::Face).each { |f| f.material=mat; f.back_material=mat }
        pg.layer = tag_for(model, part['role'])
        pg.transformation = Geom::Transformation.translation([part['x'].mm,part['y'].mm,part['z'].mm])
      end
      data['params'] = params
      group.name = "ABJ | #{params['name']} | #{data['id'].to_s[0,8]}"
      group.layer = tag_for(model, 'joinery')
      group.set_attribute(DICT, 'data', JSON.generate(data))
      group
    end

    def create(params, point)
      config = Core.normalize(params)
      model = Sketchup.active_model
      model.start_operation('ArchiBIM Joinery: Create', true)
      begin
        group = model.entities.add_group
        group.transformation = Geom::Transformation.translation([point.x, point.y, point.z + config['mount_height'].mm])
        data = { 'schema'=>Core::SCHEMA, 'id'=>SecureRandom.uuid, 'params'=>config,
                 'anchor'=>nil, 'version'=>VERSION }
        build_geometry(group, data)
        model.selection.clear
        model.selection.add(group)
        model.commit_operation
        log('created',id: data['id'], kind: config['kind'], parts: Core.parts(config).size)
        refresh
        group
      rescue StandardError => e
        model.abort_operation
        log('create_error', error: e.message)
        raise
      end
    end

    def edit_selected(params)
      group = selected_cabinet
      raise 'Select an ArchiBIM Joinery cabinet to edit' unless group
      data = data_for(group)
      merged = Core.normalize(data['params'].merge(params))
      model = group.model
      model.start_operation('ArchiBIM Joinery: Edit', true)
      begin
        data['params'] = merged
        if data['anchor']
          found = find_wall(model, data['anchor']['wall_id'])
          if found
            desc = found[1]
            data['anchor']['mount_height'] = merged['mount_height']
            fitted, frame = Core.sync_binding(desc, merged, data['anchor'])
            data['params'] = fitted
            group.transformation = to_transform(frame)
            data['anchor']['wall_signature'] = wall_signature(desc)
          end
        end
        build_geometry(group,data)
        model.commit_operation
        log('edited', id:data['id'], kind:merged['kind'])
        refresh
      rescue StandardError => e
        model.abort_operation
        raise
      end
    end

    def to_transform(frame)
      org = frame.fetch('origin').map(&:mm)
      xa = Geom::Vector3d.new(*frame.fetch('xaxis'))
      ya = Geom::Vector3d.new(*frame.fetch('yaxis'))
      za = Geom::Vector3d.new(*frame.fetch('zaxis'))
      Geom::Transformation.axes(Geom::Point3d.new(*org),xa,ya,za)
    end

    def wall_signature(wall)
      JSON.generate([wall['start'],wall['end'],wall['z'],wall['thickness'],wall['alignment'],wall['level_id']])
    end

    # Bind an existing cabinet to the real wall FACE using stable ArchiBIM UUID.
    # Pick both a cabinet and ArchiBIM wall in the SketchUp selection.
    def bind_selection(side='left',mode='fixed')
      raise ArgumentError,'Side must be left or right' unless %w[left right].include?(side)
      raise ArgumentError,'Mode must be fixed or stretch' unless Core::MODES.include?(mode)
      model = Sketchup.active_model
      group = selected_cabinet
      wall_entity = selected_wall
      raise 'Select one Joinery cabinet and one ArchiBIM wall (Ctrl-click)' unless group && wall_entity
      wall = bim_walls(model).find { |g,_| g==wall_entity }&.last
      raise 'Cannot read ArchiBIM wall' unless wall
      data = data_for(group)
      p = Core.normalize(data['params'])
      dx=wall['end'][0]-wall['start'][0]; dy=wall['end'][1]-wall['start'][1]
      len=Math.hypot(dx,dy)
      raise 'Cabinet is wider than selected wall' if len < p['width']
      bb=group.bounds.center
      cx=bb.x.to_mm; cy=bb.y.to_mm
      station=((cx-wall['start'][0])*dx + (cy-wall['start'][1])*dy)/len - p['width']/2.0
      station = [[station,0.0].max,len-p['width']].min
      anchor={ 'wall_id'=>wall['id'], 'side'=>side, 'mode'=>mode, 'station_mm'=>station,
               'end_gap_mm'=>len-station-p['width'], 'gap_mm'=>0.0,
               'mount_height'=>p['mount_height'], 'wall_signature'=>wall_signature(wall) }
      fitted,frame=Core.sync_binding(wall,p,anchor)
      model.start_operation('ArchiBIM Joinery: Bind cabinet to wall',true)
      begin
        data['anchor']=anchor
        data['params']=fitted
        group.transformation=to_transform(frame)
        build_geometry(group,data)
        model.commit_operation
        log('wall_bound', cabinet_id:data['id'], wall_id:wall['id'], side:side, mode:mode)
        refresh
      rescue StandardError
        model.abort_operation
        raise
      end
    end

    def unbind_selected
      group=selected_cabinet
      raise 'Select a Joinery cabinet first' unless group
      data=data_for(group)
      return unless data['anchor']
      model=group.model
      model.start_operation('ArchiBIM Joinery: Detach cabinet from wall',true)
      begin
        data['anchor']=nil
        group.set_attribute(DICT,'data',JSON.generate(data))
        model.commit_operation
        log('wall_detached',cabinet_id:data['id'])
        refresh
      rescue StandardError
        model.abort_operation
        raise
      end
    end

    # SketchUp's Copy/Paste clones custom attributes. Restore stable per-cabinet IDs.
    def repair_duplicate_ids(model)
      seen={}
      bad=[]
      all_cabinets(model).each do |group,data|
        uuid=data['id'].to_s
        if uuid.empty? || seen.key?(uuid)
          bad << [group,data]
        else
          seen[uuid]=true
        end
      end
      return 0 if bad.empty?
      model.start_operation('ArchiBIM Joinery: Repair copied cabinet IDs',true)
      begin
        bad.each do |group,data|
          data['id']=SecureRandom.uuid
          build_geometry(group,data)
        end
        model.commit_operation
        log('duplicate_ids_repaired',count:bad.length)
        bad.length
      rescue StandardError
        model.abort_operation
        raise
      end
    end

    def sync_all(model=Sketchup.active_model, auto:false)
      return 0 if @sync_running
      @sync_running=true
      repair_duplicate_ids(model)
      walls=bim_walls(model).to_h { |_g,w| [w['id'],w] }
      changes=[]
      all_cabinets(model).each do |group,data|
        anchor=data['anchor']
        next unless anchor && anchor['wall_id']
        wall=walls[anchor['wall_id']]
        unless wall
          log('missing_host',cabinet_id:data['id'],wall_id:anchor['wall_id'])
          next
        end
        signature=wall_signature(wall)
        next if anchor['wall_signature']==signature
        begin
          p,frame=Core.sync_binding(wall,data['params'],anchor)
          changes << [group,data,p,frame,signature]
        rescue StandardError => e
          log('host_conflict', cabinet_id:data['id'],wall_id:anchor['wall_id'],reason:e.message)
          next
        end
      end
      return 0 if changes.empty?
      model.start_operation('ArchiBIM Joinery: Update hosted cabinets',true)
      begin
        changes.each do |group,data,p,frame,sig|
          data['params']=p
          data['anchor']['wall_signature']=sig
          group.transformation=to_transform(frame)
          build_geometry(group,data)
        end
        model.commit_operation
        log('sync',count:changes.size,auto:auto)
        refresh
        changes.size
      rescue StandardError => e
        model.abort_operation
        log('sync_error',error:e.message)
        raise
      ensure
        @sync_running=false
      end
    ensure
      @sync_running=false
    end

    def queue_sync(model)
      return unless @auto_sync
      return if @sync_running || @sync_queued
      @sync_queued=true
      UI.start_timer(0,false) do
        @sync_queued=false
        if Sketchup.active_model==model
          begin
            sync_all(model,auto:true)
          rescue StandardError => e
            log('auto_sync_error',error:e.message)
          end
        end
      end
    end

    class SelectionWatcher < Sketchup::SelectionObserver
      def onSelectionBulkChange(_selection); ArchiBIMJoinery.refresh; end
      def onSelectionAdded(_selection,_entity); ArchiBIMJoinery.refresh; end
      def onSelectionRemoved(_selection,_entity); ArchiBIMJoinery.refresh; end
      def onSelectionCleared(_selection); ArchiBIMJoinery.refresh; end
    end

    class TransactionWatcher < Sketchup::ModelObserver
      def onTransactionCommit(model); ArchiBIMJoinery.queue_sync(model); end
      def onTransactionUndo(model); ArchiBIMJoinery.queue_sync(model); end
      def onTransactionRedo(model); ArchiBIMJoinery.queue_sync(model); end
    end

    class AppWatcher < Sketchup::AppObserver
      def onNewModel(model); ArchiBIMJoinery.watch(model); end
      def onOpenModel(model); ArchiBIMJoinery.watch(model); end
      def onActivateModel(model); ArchiBIMJoinery.watch(model); end
    end

    def watch(model)
      key=model.object_id
      return if @watchers.key?(key)
      obs=TransactionWatcher.new
      model.add_observer(obs)
      selection_obs=SelectionWatcher.new
      model.selection.add_observer(selection_obs)
      @watchers[key]=[obs,selection_obs]
      log('watch_model',model:key)
    end

    class PlacementTool
      def initialize(params); @params=Core.normalize(params); @input=Sketchup::InputPoint.new; end
      def activate
        Sketchup.status_text='Joinery: click a point. Arrows: Right=X, Left=Y, Up=Z, Down=unlock. Esc cancels.'
      end
      def onKeyDown(key,_repeat,_flags,view)
        direction=case key
        when VK_RIGHT then [1,0,0]
        when VK_LEFT then [0,1,0]
        when VK_UP then [0,0,1]
        when VK_DOWN then nil
        else return false
        end
        if direction
          base=@input.valid? ? @input.position : ORIGIN
          a=Sketchup::InputPoint.new(base)
          b=Sketchup::InputPoint.new(base.offset(Geom::Vector3d.new(*direction),100.mm))
          view.lock_inference(a,b)
          Sketchup.status_text="Joinery: #{direction==[1,0,0] ? 'X' : (direction==[0,1,0] ? 'Y' : 'Z')} axis locked. Down arrow unlocks."
        else
          view.lock_inference
          Sketchup.status_text='Joinery: axes unlocked.'
        end
        view.invalidate
        true
      end
      def deactivate(view)
        view.lock_inference if view
      end
      def onMouseMove(_flags,x,y,view)
        @input.pick(view,x,y)
        view.tooltip=@input.tooltip if @input.valid?
        view.invalidate
      end
      def draw(view)
        return unless @input.valid?
        @input.draw(view)
        origin=@input.position.offset(Z_AXIS,@params['mount_height'].mm)
        w=@params['width'].mm; d=@params['depth'].mm; h=@params['height'].mm
        p=[Geom::Point3d.new(0,0,0),Geom::Point3d.new(w,0,0),Geom::Point3d.new(w,d,0),Geom::Point3d.new(0,d,0),
           Geom::Point3d.new(0,0,h),Geom::Point3d.new(w,0,h),Geom::Point3d.new(w,d,h),Geom::Point3d.new(0,d,h)].map do |v|
          v.offset(origin - ORIGIN)
        end
        edges=[[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
        view.drawing_color=Sketchup::Color.new(19,149,150)
        view.line_width=2
        view.draw(GL_LINES,edges.flat_map { |a,b| [p[a],p[b]] })
      end
      def getExtents
        bb=Geom::BoundingBox.new
        bb.add(@input.position) if @input.valid?
        bb
      end
      def onLButtonDown(_flags,x,y,view)
        @input.pick(view,x,y)
        return unless @input.valid?
        ArchiBIMJoinery.create(@params,@input.position)
        Sketchup.active_model.select_tool(nil)
      rescue StandardError => e
        UI.messagebox("Joinery placement failed: #{e.message}")
      end
      def onCancel(_reason,view)
        Sketchup.active_model.select_tool(nil)
        view.invalidate
      end
    end

    def export_cutlist
      model=Sketchup.active_model
      entries=all_cabinets(model)
      raise 'No Joinery cabinets found in this model' if entries.empty?
      file=UI.savepanel('Export Joinery Cutlist (preliminary)','', 'ArchiBIM_Joinery_Cutlist.csv')
      return unless file
      CSV.open(file,'wb',write_headers:true,headers:%w[Cabinet_ID Cabinet_Name Part Role Material Length_mm Width_mm Thickness_mm Quantity Edge_Banding Status]) do |csv|
        entries.each do |_g,data|
          Core.cutlist(data['params']).each do |item|
            csv << [data['id'],data['params']['name'],item['part'],item['role'],item['material'],
                    item['length_mm'],item['width_mm'],item['thickness_mm'],item['quantity'],
                    item['edge_banding'],'PRELIMINARY - Verify joinery/hardware']
          end
        end
      end
      log('cutlist_export',file:file,cabinets:entries.size)
      UI.messagebox("Joinery cutlist exported to:\n#{file}\n\nPRELIMINARY: validate hardware clearances, grain and edging before manufacturing.")
    end

    def export_schedule
      model=Sketchup.active_model
      entries=all_cabinets(model)
      raise 'No Joinery cabinets found in this model' if entries.empty?
      file=UI.savepanel('Export BIM Joinery Schedule','', 'ArchiBIM_Joinery_Schedule.csv')
      return unless file
      CSV.open(file,'wb',write_headers:true,headers:%w[ID Description Type Width_mm Height_mm Depth_mm Carcass_mm Back_mm Front_mm Worktop_mm ToeKick_mm Material Host_Wall_ID Level_Status]) do |csv|
        entries.each do |_group,data|
          p=Core.normalize(data['params'])
          anchor=data['anchor'] || {}
          csv << [data['id'],p['name'],p['kind'],p['width'],p['height'],p['depth'],
                  p['panel_thickness'],p['back_thickness'],p['front_thickness'],p['top_thickness'],
                  p['toe_height'],p['material'],anchor['wall_id'], anchor.empty? ? 'Unhosted' : 'Wall hosted']
        end
      end
      log('schedule_export',file:file,cabinets:entries.size)
      UI.messagebox("Joinery BIM schedule exported to:\n#{file}")
    end

    def selected_payload
      group=selected_cabinet
      data=group && data_for(group)
      { version:VERSION, selected:data, cabinet_count:all_cabinets.size, wall_count:bim_walls.size,
        auto_sync:@auto_sync, recent_logs:@log.last(15) }
    end

    def refresh
      return unless @dialog && @dialog.visible?
      @dialog.execute_script("window.joineryRefresh(#{JSON.generate(selected_payload)});")
    rescue StandardError => e
      log('refresh_error',error:e.message)
    end

    def display
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        refresh
        return
      end
      @dialog=UI::HtmlDialog.new(dialog_title:'ArchiBIM Joinery',preferences_key:'SSDigitalLab_ArchiBIMJoinery',
                                 scrollable:true,resizable:true,width:465,height:800,min_width:380,min_height:500,
                                 style:UI::HtmlDialog::STYLE_DIALOG)
      @dialog.set_file(File.join(__dir__,'ui','panel.html'))
      @dialog.add_action_callback('ready') { |_ctx| refresh }
      @dialog.add_action_callback('preset') do |_ctx,kind|
        @dialog.execute_script("window.joineryPreset(#{JSON.generate(Core.presets(kind.to_s))});")
      rescue StandardError => e
        UI.messagebox(e.message)
      end
      @dialog.add_action_callback('place') do |_ctx,raw|
        begin
          Sketchup.active_model.select_tool(PlacementTool.new(JSON.parse(raw)))
        rescue StandardError => e
          UI.messagebox("Joinery: #{e.message}")
        end
      end
      @dialog.add_action_callback('edit') do |_ctx,raw|
        begin
          edit_selected(JSON.parse(raw))
        rescue StandardError => e
          UI.messagebox("Joinery: #{e.message}")
        end
      end
      @dialog.add_action_callback('bind') do |_ctx,side,mode|
        begin
          bind_selection(side,mode)
        rescue StandardError => e
          UI.messagebox("Joinery binding: #{e.message}")
        end
      end
      @dialog.add_action_callback('detach') do |_ctx|
        begin
          unbind_selected
        rescue StandardError => e
          UI.messagebox("Joinery: #{e.message}")
        end
      end
      @dialog.add_action_callback('sync') do |_ctx|
        begin
          n=sync_all
          UI.messagebox("Synchronized #{n} cabinet(s). Check Ruby Console for binding conflicts.")
        rescue StandardError => e
          UI.messagebox("Joinery sync: #{e.message}")
        end
      end
      @dialog.add_action_callback('export') do |_ctx|
        begin
          export_cutlist
        rescue StandardError => e
          UI.messagebox("Joinery export: #{e.message}")
        end
      end
      @dialog.add_action_callback('schedule') do |_ctx|
        begin
          export_schedule
        rescue StandardError => e
          UI.messagebox("Joinery schedule: #{e.message}")
        end
      end
      @dialog.add_action_callback('auto_sync') do |_ctx,flag|
        @auto_sync = flag == true || flag.to_s == 'true'
        log('auto_sync_setting',enabled:@auto_sync)
        refresh
      end
      @dialog.show
      refresh
    end

    watch(Sketchup.active_model)
    @app_watcher=AppWatcher.new
    Sketchup.add_observer(@app_watcher)
    unless defined?(@menu_registered) && @menu_registered
      menu=UI.menu('Extensions').add_submenu('ArchiBIM Joinery')
      menu.add_item('Joinery Manager') { display }
      menu.add_item('Sync Hosted Cabinets') { sync_all }
      menu.add_item('Export Preliminary Cutlist CSV') { export_cutlist }
      menu.add_item('Export BIM Joinery Schedule CSV') { export_schedule }
      @menu_registered=true
      toolbar=UI::Toolbar.new('ArchiBIM Joinery')
      command=UI::Command.new('Joinery Manager') { display }
      command.tooltip='ArchiBIM Joinery Manager'
      command.status_bar_text='Create and edit parametric interior joinery'
      toolbar.add_item(command)
      toolbar.restore
    end
    log('loaded',version:VERSION)
  end
end
