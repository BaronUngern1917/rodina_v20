Add-Type -AssemblyName PresentationCore,WindowsBase,PresentationFramework
$ErrorActionPreference = 'Stop'
$videoPath = [System.IO.Path]::GetFullPath('assets/cutscenes/chapter_02/chapter_2_good_ending.mp4')
$player = [System.Windows.Media.MediaPlayer]::new()
$player.ScrubbingEnabled = $true
$player.Volume = 0
$script:mediaOpened = $false
$player.add_MediaOpened({ $script:mediaOpened = $true })
$player.Open([Uri]::new($videoPath))
$dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
$frame = [System.Windows.Threading.DispatcherFrame]::new()
$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(30)
$timer.Add_Tick({ if ($script:mediaOpened) { $timer.Stop(); $frame.Continue = $false } })
$timer.Start()
[System.Windows.Threading.Dispatcher]::PushFrame($frame)
if (-not $player.NaturalDuration.HasTimeSpan) { throw 'Video duration was not read.' }
$duration = $player.NaturalDuration.TimeSpan
$player.Position = [TimeSpan]::FromMilliseconds([Math]::Min(800, $duration.TotalMilliseconds / 3))
$player.Play()
$script:seekDone = $false
$frame2 = [System.Windows.Threading.DispatcherFrame]::new()
$timer2 = [System.Windows.Threading.DispatcherTimer]::new()
$timer2.Interval = [TimeSpan]::FromMilliseconds(160)
$timer2.Add_Tick({ $player.Pause(); $timer2.Stop(); $frame2.Continue = $false })
$timer2.Start()
[System.Windows.Threading.Dispatcher]::PushFrame($frame2)
$visual = [System.Windows.Media.DrawingVisual]::new()
$context = $visual.RenderOpen()
$videoDrawing = [System.Windows.Media.VideoDrawing]::new()
$videoDrawing.Player = $player
$videoDrawing.Rect = [System.Windows.Rect]::new(0,0,1280,720)
$context.DrawDrawing($videoDrawing)
$context.Close()
$bitmap = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(1280,720,96,96,[System.Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($visual)
$encoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
$encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$output = [System.IO.File]::Create([System.IO.Path]::GetFullPath('__chapter3_video_test.png'))
$encoder.Save($output)
$output.Close()
"VIDEO_HAS_IMAGE=$($player.HasVideo) DURATION=$($duration.TotalSeconds) FRAME=$([System.IO.FileInfo]::new('__chapter3_video_test.png').Length)"
$player.Close()
