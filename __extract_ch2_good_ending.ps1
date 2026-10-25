Add-Type -AssemblyName PresentationCore,WindowsBase,PresentationFramework
$ErrorActionPreference = 'Stop'
$videoPath = [System.IO.Path]::GetFullPath('assets/cutscenes/chapter_02/chapter_2_good_ending.mp4')
$outputDirectory = [System.IO.Path]::GetFullPath('assets/cutscenes/chapter_02/good_ending_frames')
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
$player = [System.Windows.Media.MediaPlayer]::new()
$player.ScrubbingEnabled = $true
$player.Volume = 0
$script:mediaOpened = $false
$player.add_MediaOpened({ $script:mediaOpened = $true })
$player.Open([Uri]::new($videoPath))
$dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
$frame = [System.Windows.Threading.DispatcherFrame]::new()
$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(25)
$timer.Add_Tick({ if ($script:mediaOpened) { $timer.Stop(); $frame.Continue = $false } })
$timer.Start()
[System.Windows.Threading.Dispatcher]::PushFrame($frame)
if (-not $player.NaturalDuration.HasTimeSpan) { throw 'Could not read the victory video duration.' }
$duration = $player.NaturalDuration.TimeSpan
$fps = 15.0
$frameCount = [int][Math]::Ceiling($duration.TotalSeconds * $fps)
$visual = [System.Windows.Media.DrawingVisual]::new()
$context = $visual.RenderOpen()
$videoDrawing = [System.Windows.Media.VideoDrawing]::new()
$videoDrawing.Player = $player
$videoDrawing.Rect = [System.Windows.Rect]::new(0,0,1280,720)
$context.DrawDrawing($videoDrawing)
$context.Close()
$dispatcherTimer = [System.Windows.Threading.DispatcherTimer]::new()
for ($index = 0; $index -lt $frameCount; $index++) {
    $timeMs = [int][Math]::Min(($duration.TotalMilliseconds - 1), ([Math]::Round($index * 1000.0 / $fps)))
    $player.Position = [TimeSpan]::FromMilliseconds($timeMs)
    $player.Play()
    $waitFrame = [System.Windows.Threading.DispatcherFrame]::new()
    $waitTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $waitTimer.Interval = [TimeSpan]::FromMilliseconds(105)
    $waitTimer.Add_Tick({ $player.Pause(); $waitTimer.Stop(); $waitFrame.Continue = $false })
    $waitTimer.Start()
    [System.Windows.Threading.Dispatcher]::PushFrame($waitFrame)
    $bitmap = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(1280,720,96,96,[System.Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder = [System.Windows.Media.Imaging.JpegBitmapEncoder]::new()
    $encoder.QualityLevel = 86
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $framePath = Join-Path $outputDirectory ('frame_{0:D4}.jpg' -f $index)
    $stream = [System.IO.File]::Create($framePath)
    $encoder.Save($stream)
    $stream.Close()
}
"FRAMES=$frameCount FPS=$fps DURATION=$($duration.TotalSeconds) OUTPUT=$outputDirectory"
$player.Close()
