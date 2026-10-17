# Ninety iOS — adds the «Share» extension target (NinetyShare) to the generated Capacitor project and embeds it in the app.
# Run from ios-app/ after `npx cap add ios` (scripts/configure-ios.py calls it only when the extension's provisioning profile
# was installed by scripts/share-signing.py — without the profile the app builds as before, without the extension).
require 'xcodeproj'
require 'fileutils'

proj_path = 'ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(proj_path)
app = project.targets.find { |t| t.name == 'App' } or abort('App target not found')
if project.targets.any? { |t| t.name == 'NinetyShare' }
  puts 'share extension already there'
  exit 0
end

dir = 'ios/App/NinetyShare'
FileUtils.mkdir_p(dir)
%w[ShareViewController.swift Info.plist NinetyShare.entitlements].each { |f| FileUtils.cp(File.join('share-ext', f), File.join(dir, f)) }

app_cfg = app.build_configurations.find { |c| c.name == 'Release' } || app.build_configurations.first
mv = app_cfg.build_settings['MARKETING_VERSION'] || '1.0'
cv = app_cfg.build_settings['CURRENT_PROJECT_VERSION'] || '1'

ext = project.new_target(:app_extension, 'NinetyShare', :ios, '15.0', nil, :swift)
group = project.main_group.new_group('NinetyShare', 'NinetyShare')
src = group.new_reference('ShareViewController.swift')
group.new_reference('Info.plist')
group.new_reference('NinetyShare.entitlements')
ext.add_file_references([src])

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'app.ninety.fabrication.share'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = 'NinetyShare/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = 'NinetyShare/NinetyShare.entitlements'
  s['DEVELOPMENT_TEAM'] = 'UF4QLJ9AY9'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['MARKETING_VERSION'] = mv
  s['CURRENT_PROJECT_VERSION'] = cv
  s['VERSIONING_SYSTEM'] = 'apple-generic'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['ENABLE_BITCODE'] = 'NO'
end

embed = app.copy_files_build_phases.find { |p| p.dst_subfolder_spec == '13' } || app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.dst_subfolder_spec = '13'
# right after «Frameworks» (an embed phase after a script phase can make Xcode report a dependency cycle)
app.build_phases.delete(embed)
fw = app.build_phases.index(app.frameworks_build_phase)
app.build_phases.insert(fw ? fw + 1 : app.build_phases.length, embed)
bf = embed.add_file_reference(ext.product_reference, true)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
app.add_dependency(ext)

project.save
puts "share extension added (version #{mv} / #{cv})"
