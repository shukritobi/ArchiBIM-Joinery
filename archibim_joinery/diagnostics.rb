# frozen_string_literal: true
# Crash-resilient ArchiBIM Joinery diagnostic + UI event capture, plain-Ruby ZIP.
require 'json'
require 'csv'
require 'zlib'
require 'time'
require 'tmpdir'
require 'fileutils'
require_relative 'v04_runtime'

module SSDigitalLab
  module ArchiBIMJoinery
    module Diagnostics
      def log(event, fields={})
        item=super
        diagnostic_append({'source'=>'ruby'}.merge(item))
        item
      end

      def diagnostic_append(event)
        @ui_events ||= []
        if event['source']=='ui'
          @ui_events << event
          @ui_events.shift while @ui_events.size>1500
        end
        path=File.join(Dir.tmpdir,'ArchiBIM_Joinery_session_events.jsonl')
        File.open(path,'ab') {|f| f.write(JSON.generate(event)+"\n") }
      rescue StandardError
        # Diagnostics must never stop the user's geometry operation.
        nil
      end

      def diagnostic_ui_event(raw)
        event=JSON.parse(raw.to_s)
        raise ArgumentError,'Invalid UI event' unless event.is_a?(Hash)
        # Only known fields, bounded strings. Never trust arbitrary dialog input.
        allowed=%w[at action control kind family value status message stack
                   width height scroll_y input_type]
        normalized={}
        allowed.each do |key|
          val=event[key]
          normalized[key]=val.to_s[0,1500] unless val.nil?
        end
        normalized['source']='ui'
        diagnostic_append(normalized)
      rescue StandardError => e
        log('ui_event_decode_error',error:e.message)
      end

      def diagnostic_ui_snapshot(raw)
        snapshot=JSON.parse(raw.to_s)
        raise ArgumentError,'Invalid snapshot' unless snapshot.is_a?(Hash)
        @ui_snapshot=snapshot.transform_keys(&:to_s)
        diagnostic_append({'source'=>'ui','action'=>'snapshot',
                           'at'=>Time.now.utc.iso8601,
                           'width'=>@ui_snapshot['width'].to_s,
                           'height'=>@ui_snapshot['height'].to_s,
                           'family'=>@ui_snapshot['kind'].to_s})
      rescue StandardError => e
        log('ui_snapshot_error',error:e.message)
      end

      def diagnostic_inventory
        m=Sketchup.active_model
        units=[]
        warnings=[]
        all_cabinets(m).first(600).each do |group,data|
          p=data['params']
          child=group.entities.grep(Sketchup::Group)
          parts=child.filter_map do |g|
            raw=g.get_attribute(DICT,'part_data')
            next unless raw
            JSON.parse(raw) rescue nil
          end
          checks=[]
          begin
            norm=Core.normalize(p)
            expected=Core.parts(norm)
            keys=parts.map{|r|r['key']}
            missing=expected.map{|r|r['key']}-keys
            extra=keys-expected.map{|r|r['key']}
            checks<<{'type'=>'part_mismatch','missing'=>missing,'extra'=>extra} unless missing.empty? && extra.empty?
            if norm['kind']=='wall' && norm['top_shadow_gap'].to_f>0
              checks<<{'type'=>'unexpected_wall_top_shadow','gap_mm'=>norm['top_shadow_gap']}
            end
            if norm['kind']=='wall_panel' && parts.none?{|r|r['role']=='wall_panel'}
              checks<<{'type'=>'missing_wall_panel_mesh'}
            end
            if norm['kind']=='basin_vanity' && norm['mirror_enabled'] && parts.none?{|r|r['role']=='mirror'}
              checks<<{'type'=>'missing_vanity_mirror'}
            end
            checks<<{'type'=>'invalid_part_dimensions'} if parts.any?{|r|r.values_at('w','d','h').any?{|n|n.to_f<=0}}
          rescue StandardError => e
            checks<<{'type'=>'normalization_error','error'=>e.message}
          end
          warnings << {'id'=>data['id'],'kind'=>p['kind'],'checks'=>checks} unless checks.empty?
          units << {'id'=>data['id'],'kind'=>p['kind'],'name'=>p['name'],
                    'params'=>p,'anchor'=>data['anchor'],
                    'part_count'=>parts.size,'parts'=>parts,
                    'checks'=>checks,
                    'transform'=>group.transformation.to_a,
                    'visible'=>group.visible?,
                    'layer'=>group.layer.name}
        end
        {
          'model_path'=>m.path.to_s,
          'sketchup_version'=>Sketchup.version,
          'ruby_version'=>RUBY_VERSION,
          'plugin_version'=>VERSION,
          'cabinet_count'=>all_cabinets(m).size,
          'wall_count'=>bim_walls(m).size,
          'selection_count'=>m.selection.length,
          'units'=>units,'warnings'=>warnings
        }
      end

      def diagnostic_report
        inventory=diagnostic_inventory
        {'schema'=>'archibim-joinery-qa/v1',
         'generated_at'=>Time.now.utc.iso8601,
         'environment'=>{'ruby'=>RUBY_VERSION,'sketchup'=>Sketchup.version,
                         'plugin'=>VERSION,'platform'=>RUBY_PLATFORM},
         'inventory'=>inventory,
         'events'=>(@log||[]).last(500),
         'ui_events'=>(@ui_events||[]).last(1500),
         'ui_snapshot'=>@ui_snapshot || {}}
      end

      def diagnostic_text(report)
        inv=report['inventory']
        lines=["ARCHIBIM JOINERY DIAGNOSIS REPORT",
               "Generated: #{report['generated_at']}",
               "SketchUp: #{report['environment']['sketchup']} | Plugin: #{VERSION}",
               "Model: #{inv['model_path']}",
               "Cabinets: #{inv['cabinet_count']} | Walls: #{inv['wall_count']}",
               "Warnings: #{inv['warnings'].size}",
               ""]
        inv['warnings'].each do |warning|
          lines << "[WARNING] #{warning['kind']} #{warning['id']}"
          warning['checks'].each{|check| lines << "  #{JSON.generate(check)}"}
        end
        lines << ""
        lines << "RECENT PLUGIN EVENTS:"
        report['events'].last(150).each{|e|lines << JSON.generate(e)}
        lines << ""
        lines << "RECENT UI EVENTS:"
        report['ui_events'].last(150).each{|e|lines << JSON.generate(e)}
        lines.join("\n")+"\n"
      end

      # Portable ZIP without shell tools or external gems (store-only ZIP).
      def diagnostics_zip(entries)
        local=''.b; central=''.b
        entries.each do |name,value|
          filename=name.to_s.encode('UTF-8').b
          payload=value.to_s.b
          crc=Zlib.crc32(payload)
          size=payload.bytesize
          offset=local.bytesize
          local << [0x04034b50,20,0,0,0,0,crc,size,size,
                    filename.bytesize,0].pack('VvvvvvVVVvv')
          local << filename << payload
          central << [0x02014b50,20,20,0,0,0,0,crc,size,size,
                       filename.bytesize,0,0,0,0,0,offset].
                         pack('VvvvvvvVVVvvvvvVV')
          central << filename
        end
        count=entries.size
        central_offset=local.bytesize
        local << central
        local << [0x06054b50,0,0,count,count,
                  central.bytesize,central_offset,0].pack('VvvvvVVv')
        local
      end

      def export_diagnostic_bundle
        file=UI.savepanel('Save Joinery QA Report + UI Logs ZIP','',
                          'ArchiBIM_Joinery_QA_LATEST.zip')
        return nil unless file
        file += '.zip' unless file.downcase.end_with?('.zip')
        report=diagnostic_report
        entries={
          'DIAGNOSIS_REPORT.txt'=>diagnostic_text(report),
          'DIAGNOSIS_REPORT.json'=>JSON.pretty_generate(report),
          'UI_REPORT.json'=>JSON.pretty_generate({
            'schema'=>'archibim-joinery-ui/v1',
            'snapshot'=>report['ui_snapshot'],
            'events'=>report['ui_events']
          }),
          'UI_REPORT.txt'=>report['ui_events'].map{|e|JSON.generate(e)}.join("\n")+"\n",
          'PLUGIN_EVENTS.json'=>JSON.pretty_generate(report['events']),
          'README.txt'=>"ArchiBIM Joinery v#{VERSION} QA bundle\nContains model-part inventory, validation warnings, UI clicks and field-change activity, Ruby plugin events and optional screenshot. The screenshot is the current SketchUp view; no models are uploaded automatically.\n"
        }
        path=File.join(Dir.tmpdir,'ArchiBIM_Joinery_session_events.jsonl')
        if File.file?(path)
          size=File.size(path)
          File.open(path,'rb') do |f|
            f.seek([size-1_000_000,0].max)
            f.gets if size>1_000_000
            entries['SESSION_EVENTS.jsonl']=f.read || ''
          end
        end
        Dir.mktmpdir('archibim-joinery-qa-') do |dir|
          shot=File.join(dir,'SketchUp_View.png')
          begin
            ok=Sketchup.active_model.active_view.write_image(
              filename:shot,width:1200,height:760,antialias:true)
            entries['SketchUp_View.png']=File.binread(shot) if ok && File.file?(shot)
          rescue StandardError => e
            entries['SCREENSHOT_ERROR.txt']=e.message
          end
        end
        File.binwrite(file,diagnostics_zip(entries))
        log('diagnostic_bundle_export',file:file,bytes:File.size(file),
            warnings:report['inventory']['warnings'].size)
        UI.messagebox("Joinery QA bundle exported:\n#{file}\n\nIncludes diagnosis, UI logs, plugin events and a viewport screenshot if supported.")
        file
      rescue StandardError => e
        log('diagnostic_export_error',error:e.message,
            backtrace:e.backtrace&.first(5))
        UI.messagebox("Joinery diagnostics: #{e.message}")
        nil
      end

      def display
        existing=@dialog && @dialog.visible?
        super
        return if existing
        @dialog.add_action_callback('diagnostic_event') do |_ctx,raw|
          diagnostic_ui_event(raw)
        end
        @dialog.add_action_callback('diagnostic_snapshot') do |_ctx,raw|
          diagnostic_ui_snapshot(raw)
        end
        @dialog.add_action_callback('diagnostic_export') do |_ctx|
          export_diagnostic_bundle
        end
      end
    end

    singleton_class.prepend(Diagnostics)
    unless defined?(@diag_menu_registered) && @diag_menu_registered
      menu=UI.menu('Extensions').add_submenu('ArchiBIM Joinery: Diagnostics')
      menu.add_item('Export Diagnosis + UI Logs ZIP') { export_diagnostic_bundle }
      @diag_menu_registered=true
    end
  end
end
