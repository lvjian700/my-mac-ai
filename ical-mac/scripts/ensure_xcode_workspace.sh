#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$ROOT/.swiftpm/xcode/package.xcworkspace"
SHARED_SCHEMES="$ROOT/.swiftpm/xcode/xcshareddata/xcschemes"
USER_SCHEMES="$ROOT/.swiftpm/xcode/xcuserdata/$(id -un).xcuserdatad/xcschemes"

mkdir -p "$WORKSPACE"
cat > "$WORKSPACE/contents.xcworkspacedata" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
XML

mkdir -p "$SHARED_SCHEMES" "$USER_SCHEMES"
cat > "$SHARED_SCHEMES/ICalMacUI.xcscheme" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2640"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "ICalMacUI"
               BuildableName = "ICalMacUI"
               BlueprintName = "ICalMacUI"
               ReferencedContainer = "container:">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "ICalMacUITests"
               BuildableName = "ICalMacUITests"
               BlueprintName = "ICalMacUITests"
               ReferencedContainer = "container:">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES"
      queueDebuggingEnableBacktraceRecording = "Yes">
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "ICalMacUI"
            BuildableName = "ICalMacUI"
            BlueprintName = "ICalMacUI"
            ReferencedContainer = "container:">
         </BuildableReference>
      </MacroExpansion>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
XML

cat > "$USER_SCHEMES/xcschememanagement.plist" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>SchemeUserState</key>
	<dict>
		<key>ICalMacUI.xcscheme_^#shared#^_</key>
		<dict>
			<key>orderHint</key>
			<integer>0</integer>
		</dict>
		<key>ical-mac.xcscheme_^#shared#^_</key>
		<dict>
			<key>orderHint</key>
			<integer>1</integer>
		</dict>
		<key>ical-mac-Package.xcscheme_^#shared#^_</key>
		<dict>
			<key>orderHint</key>
			<integer>2</integer>
		</dict>
		<key>ICalMacCore.xcscheme_^#shared#^_</key>
		<dict>
			<key>orderHint</key>
			<integer>3</integer>
		</dict>
	</dict>
	<key>SuppressBuildableAutocreation</key>
	<dict>
		<key>ICalMacCore</key>
		<dict>
			<key>primary</key>
			<true/>
		</dict>
		<key>ICalMacCoreTests</key>
		<dict>
			<key>primary</key>
			<true/>
		</dict>
		<key>ICalMacUI</key>
		<dict>
			<key>primary</key>
			<true/>
		</dict>
		<key>ICalMacUITests</key>
		<dict>
			<key>primary</key>
			<true/>
		</dict>
		<key>ical-mac</key>
		<dict>
			<key>primary</key>
			<true/>
		</dict>
	</dict>
</dict>
</plist>
XML

echo "$WORKSPACE"
