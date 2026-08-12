[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$toolchains=Get-Content (Join-Path $root 'config\toolchains.json') -Raw|ConvertFrom-Json
$sdk=[string]$toolchains.android.sdkRoot;$javaHome=[string]$toolchains.java.javaHome
if(-not(Test-Path $sdk)){throw '[FAIL] Android SDK root'}
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-android-gold-'+[guid]::NewGuid().ToString('N'))
try{
  New-Item -ItemType Directory -Force (Join-Path $tmp 'app\src\main\java\eval'),(Join-Path $tmp 'app\src\main\res\values'),(Join-Path $tmp 'app\src\main\res\xml'),(Join-Path $tmp 'app\src\test\java\eval')|Out-Null
  $wrapperDir=Join-Path $tmp 'wrapper-bootstrap';New-Item -ItemType Directory -Force $wrapperDir|Out-Null
  ''|Set-Content -Encoding ASCII (Join-Path $wrapperDir 'settings.gradle');''|Set-Content -Encoding ASCII (Join-Path $wrapperDir 'build.gradle')
  $wrapperJavaHome=$env:JAVA_HOME
  try{$env:JAVA_HOME='C:\Program Files\Java\jdk-17.0.12';& gradle -p $wrapperDir --no-daemon -q wrapper --gradle-version 9.5.0;if($LASTEXITCODE -ne 0){throw '[FAIL] Android Gradle 9.5 wrapper generation'}}finally{$env:JAVA_HOME=$wrapperJavaHome}
  Copy-Item -LiteralPath (Join-Path $wrapperDir 'gradle') -Destination $tmp -Recurse -Force;Copy-Item -LiteralPath (Join-Path $wrapperDir 'gradlew.bat') -Destination $tmp -Force
  'pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }; dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }; rootProject.name="android-gold"; include(":app")'|Set-Content -Encoding ASCII (Join-Path $tmp 'settings.gradle')
  'plugins { id "com.android.application" version "8.12.1" apply false }'|Set-Content -Encoding ASCII (Join-Path $tmp 'build.gradle')
  @'
plugins { id 'com.android.application' }
android { namespace 'eval.android'; compileSdk 36
 defaultConfig { applicationId 'eval.android'; minSdk 23; targetSdk 36; versionCode 1; versionName '1' }
 compileOptions { sourceCompatibility JavaVersion.VERSION_21; targetCompatibility JavaVersion.VERSION_21 }
 lint { warningsAsErrors true; abortOnError true; disable 'OldTargetApi' }
}
dependencies { testImplementation 'junit:junit:4.13.2' }
'@|Set-Content -Encoding ASCII (Join-Path $tmp 'app\build.gradle')
  '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:theme="@style/AppTheme" android:label="@string/app_name" android:allowBackup="false" android:fullBackupContent="@xml/backup_rules" android:dataExtractionRules="@xml/data_extraction_rules" android:supportsRtl="true"/></manifest>'|Set-Content -Encoding ASCII (Join-Path $tmp 'app\src\main\AndroidManifest.xml')
  '<resources><string name="app_name">Gold</string><style name="AppTheme" parent="android:style/Theme.Material.Light.NoActionBar"/></resources>'|Set-Content -Encoding UTF8 (Join-Path $tmp 'app\src\main\res\values\values.xml')
  '<full-backup-content><exclude domain="root" path="."/></full-backup-content>'|Set-Content -Encoding ASCII (Join-Path $tmp 'app\src\main\res\xml\backup_rules.xml')
  '<data-extraction-rules><cloud-backup disableIfNoEncryptionCapabilities="true"><exclude domain="root" path="."/></cloud-backup><device-transfer><exclude domain="root" path="."/></device-transfer></data-extraction-rules>'|Set-Content -Encoding ASCII (Join-Path $tmp 'app\src\main\res\xml\data_extraction_rules.xml')
  'package eval; public final class Slug { private Slug(){} public static String of(String v){if(v==null||v.trim().isEmpty())throw new IllegalArgumentException();return v.trim().toLowerCase(java.util.Locale.ROOT).replaceAll("[^a-z0-9]+","-").replaceAll("(^-|-$)","");}}'|Set-Content -Encoding ASCII (Join-Path $tmp 'app\src\main\java\eval\Slug.java')
  'package eval; import static org.junit.Assert.*; import org.junit.Test; public class SlugTest {@Test public void normalizes(){assertEquals("hello-21",Slug.of(" Hello 21 "));}@Test(expected=IllegalArgumentException.class) public void rejectsBlank(){Slug.of(" ");}}'|Set-Content -Encoding ASCII (Join-Path $tmp 'app\src\test\java\eval\SlugTest.java')
  Push-Location $tmp
  try{$oldJava=$env:JAVA_HOME;$oldAndroid=$env:ANDROID_HOME;$oldPath=$env:Path;$env:JAVA_HOME=$javaHome;$env:ANDROID_HOME=$sdk;$env:Path=(Join-Path $javaHome 'bin')+';C:\Windows\System32;C:\Windows;'+(Join-Path $sdk 'platform-tools')+';'+(Join-Path $sdk 'build-tools\36.0.0');& .\gradlew.bat --no-daemon -q :app:testDebugUnitTest :app:lintDebug :app:assembleDebug;if($LASTEXITCODE -ne 0){throw '[FAIL] Android unit/lint/assemble'}}finally{$env:JAVA_HOME=$oldJava;$env:ANDROID_HOME=$oldAndroid;$env:Path=$oldPath;Pop-Location}
  if(-not(Test-Path (Join-Path $tmp 'app\build\outputs\apk\debug\app-debug.apk'))){throw '[FAIL] Android APK evidence'}
}finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
Write-Host '[PASS] Android SDK 36 unit, lint, manifest/resources and assemble gates on Temurin 21' -ForegroundColor Green








