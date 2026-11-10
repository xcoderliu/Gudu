#!/usr/bin/env python3
"""Regenerate the small, dependency-free Xcode project from checked-in sources."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Gudu.xcodeproj"


def uid(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()


def quote(value):
    return '"' + str(value).replace('"', '\\"') + '"'


objects = []


def obj(key, body):
    objects.append(f"\t\t{uid(key)} = {{ {body} }};")
    return uid(key)


def group(directory, name=None):
    children = []
    for path in sorted(directory.iterdir()):
        if path.name.startswith("."):
            continue
        relative = path.relative_to(ROOT).as_posix()
        if path.is_dir() and path.suffix != ".xcassets":
            children.append(group(path))
        elif path.suffix in {".swift", ".plist", ".entitlements", ".xcassets", ".wav"}:
            filetype = {".swift": "sourcecode.swift", ".plist": "text.plist.xml",
                        ".entitlements": "text.plist.entitlements", ".xcassets": "folder.assetcatalog", ".wav": "audio.wav"}[path.suffix]
            children.append(obj("file:" + relative,
                f"isa = PBXFileReference; lastKnownFileType = {filetype}; path = {quote(path.name)}; sourceTree = \"<group>\";"))
    return obj("group:" + directory.relative_to(ROOT).as_posix(),
        f"isa = PBXGroup; children = ({', '.join(children)}); path = {quote(directory.name)}; sourceTree = \"<group>\";"
        + (f" name = {quote(name)};" if name else ""))


app_group = group(ROOT / "Gudu")
sources_group = group(ROOT / "Sources")
tests_group = group(ROOT / "Tests")
package_file = obj("file:Package.swift", 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Package.swift; sourceTree = "<group>";')
readme_file = obj("file:README.md", 'isa = PBXFileReference; lastKnownFileType = net.daringfireball.markdown; path = README.md; sourceTree = "<group>";')
product = obj("product", 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Gudu.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj("products", f'isa = PBXGroup; children = ({product}); name = Products; sourceTree = "<group>";')
main_group = obj("root", f'isa = PBXGroup; children = ({app_group}, {sources_group}, {tests_group}, {package_file}, {readme_file}, {products}); sourceTree = "<group>";')

source_builds = []
for path in sorted((ROOT / "Gudu").rglob("*.swift")):
    relative = path.relative_to(ROOT).as_posix()
    source_builds.append(obj("build:" + relative,
        f"isa = PBXBuildFile; fileRef = {uid('file:' + relative)};"))
assets = obj("build:assets", f"isa = PBXBuildFile; fileRef = {uid('file:Gudu/Resources/Assets.xcassets')};")
resource_builds = [assets]
for path in sorted((ROOT / "Gudu" / "Resources").rglob("*.wav")):
    relative = path.relative_to(ROOT).as_posix()
    resource_builds.append(obj("build:" + relative, f"isa = PBXBuildFile; fileRef = {uid('file:' + relative)};"))
package_ref = obj("localPackage", 'isa = XCLocalSwiftPackageReference; relativePath = .;')
package_product = obj("packageProduct", f'isa = XCSwiftPackageProductDependency; package = {package_ref}; productName = GuduCore;')
package_build = obj("packageBuild", f"isa = PBXBuildFile; productRef = {package_product};")

source_phase = obj("sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({', '.join(source_builds)}); runOnlyForDeploymentPostprocessing = 0;")
resource_phase = obj("resources", f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({', '.join(resource_builds)}); runOnlyForDeploymentPostprocessing = 0;")
framework_phase = obj("frameworks", f"isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({package_build}); runOnlyForDeploymentPostprocessing = 0;")

project_configs, target_configs = [], []
for config in ["Debug", "Release"]:
    debug = config == "Debug"
    common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES", "SDKROOT": "macosx", "MACOSX_DEPLOYMENT_TARGET": "14.0",
        "SWIFT_VERSION": "5.0", "SWIFT_STRICT_CONCURRENCY": "complete",
        "GCC_C_LANGUAGE_STANDARD": "gnu17", "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if debug else "-O",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG" if debug else "",
        "ENABLE_TESTABILITY": "YES" if debug else "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf" if debug else "dwarf-with-dsym",
        "ONLY_ACTIVE_ARCH": "YES" if debug else "NO",
    }
    settings = " ".join(f"{k} = {quote(v)};" for k, v in common.items())
    project_configs.append(obj("project:" + config,
        f"isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {config};"))
    target = {
        "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "local.ripple.WaterReminder",
        "INFOPLIST_FILE": "Gudu/Info.plist", "GENERATE_INFOPLIST_FILE": "NO",
        "CODE_SIGN_ENTITLEMENTS": "Gudu/Gudu.entitlements", "CODE_SIGN_IDENTITY": "-",
        "CODE_SIGN_STYLE": "Manual", "ENABLE_APP_SANDBOX": "YES", "ENABLE_HARDENED_RUNTIME": "YES",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "MARKETING_VERSION": "0.1.0",
        "CURRENT_PROJECT_VERSION": "1", "COMBINE_HIDPI_IMAGES": "YES",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
    }
    if not debug:
        target["ARCHS"] = "arm64"
    settings = " ".join(f"{k} = {quote(v)};" for k, v in target.items())
    target_configs.append(obj("target:" + config,
        f"isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {config};"))

project_config_list = obj("projectConfigs", f"isa = XCConfigurationList; buildConfigurations = ({', '.join(project_configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
target_config_list = obj("targetConfigs", f"isa = XCConfigurationList; buildConfigurations = ({', '.join(target_configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
native_target = obj("nativeTarget", f"isa = PBXNativeTarget; buildConfigurationList = {target_config_list}; buildPhases = ({source_phase}, {framework_phase}, {resource_phase}); buildRules = (); dependencies = (); name = Gudu; packageProductDependencies = ({package_product}); productName = Gudu; productReference = {product}; productType = \"com.apple.product-type.application\";")
project = obj("project", f"isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {native_target} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {project_config_list}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = zh_CN; hasScannedForEncodings = 0; knownRegions = (zh_CN, en, Base); mainGroup = {main_group}; packageReferences = ({package_ref}); productRefGroup = {products}; projectDirPath = \"\"; projectRoot = \"\"; targets = ({native_target});")

PROJECT.mkdir(exist_ok=True)
(PROJECT / "project.pbxproj").write_text(
    "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n"
    + "\n".join(objects) + f"\n\t}};\n\trootObject = {project};\n}}\n")

scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
default_scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{native_target}" BuildableName="Gudu.app" BlueprintName="Gudu" ReferencedContainer="container:Gudu.xcodeproj"/>
    </BuildActionEntry></BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{native_target}" BuildableName="Gudu.app" BlueprintName="Gudu" ReferencedContainer="container:Gudu.xcodeproj"/></BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{native_target}" BuildableName="Gudu.app" BlueprintName="Gudu" ReferencedContainer="container:Gudu.xcodeproj"/></BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
# Preserve the maintainer's launch configuration and debugger settings.
scheme_path = scheme_dir / 'Gudu.xcscheme'
if not scheme_path.exists():
    scheme_path.write_text(default_scheme)
print(f"Generated {PROJECT}")
