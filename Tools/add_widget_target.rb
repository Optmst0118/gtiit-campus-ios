#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(__dir__, '..', 'GTIIT.xcodeproj')
project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.name == 'GTIIT' }
raise 'GTIIT target missing' unless app

old = project.targets.find { |t| t.name == 'GTIITWidgets' }
if old
  app.dependencies.dup.each do |dep|
    app.dependencies.delete(dep) if dep.target == old
  end
  app.build_phases.dup.each do |phase|
    phase.remove_from_project if phase.display_name == 'Embed Foundation Extensions'
  end
  old.remove_from_project
end

widget = project.new_target(:app_extension, 'GTIITWidgets', :ios, '17.0')

widget_group = project.main_group.find_subpath('GTIITWidgets', true)
widget_group.set_source_tree('<group>')
widget_group.set_path('GTIITWidgets')
widget_sources = %w[GTIITWidgetBundle.swift ShuttleLiveActivityWidget.swift]
widget_sources.each do |name|
  ref = widget_group.new_file(name)
  widget.source_build_phase.add_file_reference(ref)
end

%w[ShuttleActivityAttributes.swift ShuttleSchedule.swift Localization.swift].each do |name|
  shared_ref = project.main_group.recursive_children.find do |f|
    f.respond_to?(:path) && f.path == name
  end
  raise "#{name} missing" unless shared_ref
  widget.source_build_phase.add_file_reference(shared_ref)
end

widget_group.new_file('Info.plist')
widget_group.new_file('GTIITWidgets.entitlements')

widget.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'io.github.optmst0118.gtiit.widgets',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'GTIITWidgets/Info.plist',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'SKIP_INSTALL' => 'YES',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'SWIFT_VERSION' => '5.0',
    'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'CURRENT_PROJECT_VERSION' => '24',
    'MARKETING_VERSION' => '2.0.0',
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  )
end

app.build_configurations.each do |config|
end

app.add_dependency(widget) unless app.dependencies.any? { |dep| dep.target == widget }
unless app.build_phases.any? { |phase| phase.display_name == 'Embed Foundation Extensions' }
  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.dst_subfolder_spec = '13'
  embed.add_file_reference(widget.product_reference)
end

project.save
puts 'widget target added'
