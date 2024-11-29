unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, process, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, ExtCtrls, utils;

type

  { TScreenRec }

  TScreenRec = class(TForm)
    Label7: TLabel;
    Second: TLabel;
    Minute: TLabel;
    PlayBtn: TButton;
    KillBtn: TButton;
    StopBtn: TButton;
    RecBtn: TButton;
    VideoFile: TEdit;
    Label6: TLabel;
    RecSize: TComboBox;
    CopyYBtn: TButton;
    Label5: TLabel;
    RecX: TEdit;
    RecY: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    PageControl1: TPageControl;
    Proc: TProcess;
    RecTab: TTabSheet;
    Timer: TTimer;
    VBoxTab: TTabSheet;
    VBoxY: TEdit;
    VCButton: TButton;
    procedure CopyYBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure KillBtnClick(Sender: TObject);
    procedure PlayBtnClick(Sender: TObject);
    procedure RecBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure VCButtonClick(Sender: TObject);
  private
    FMinute, FSecond: Integer;
    procedure AddOption(const o,p: string);
    procedure startRecording;
    function generateFileName: string;
  public

  end;

var
  ScreenRec: TScreenRec;

implementation

{$R *.lfm}

{ TScreenRec }

procedure TScreenRec.VCButtonClick(Sender: TObject);
var
  i: integer;
begin
  i:=StrToInt(VBoxY.Text);
  VBoxY.Text:=IntToStr(GetVBoxY(i));
end;

procedure TScreenRec.AddOption(const o, p: string);
begin
  Proc.Parameters.Add(o);
  Proc.Parameters.Add(p);
end;

procedure TScreenRec.startRecording;
begin
  if Proc.Active then
  begin
    ShowMessage('Process is already running.');
    Exit;
  end;

  Proc.Executable := '/usr/bin/ffmpeg';
  Proc.Parameters.Clear;
   // Proc.Parameters.Add('-f');
   // Proc.Parameters.Add('alsa');
   // Proc.Parameters.Add('-ac');
   // Proc.Parameters.Add('2');
   // Proc.Parameters.Add('-i');
   // Proc.Parameters.Add('record-n-play.monitor');     //presumably loopback

   // Screen recording parameters
   Proc.Parameters.Add('-f');
   Proc.Parameters.Add('x11grab');
   Proc.Parameters.Add('-framerate');
   Proc.Parameters.Add('25');
   Proc.Parameters.Add('-video_size');
   Proc.Parameters.Add(RecSize.Text);
   Proc.Parameters.Add('-i');
   Proc.Parameters.Add(Concat(':0.0+', RecX.Text, ',', RecY.Text));

   // Encoding options
   Proc.Parameters.Add('-c:v');
   Proc.Parameters.Add('libx264');
   Proc.Parameters.Add('-preset');
   Proc.Parameters.Add('ultrafast');
   Proc.Parameters.Add('-pix_fmt');
   Proc.Parameters.Add('yuv420p');

   // Output file
   Proc.Parameters.Add(VideoFile.Text);

   // Configure process options to enable output redirection
   Proc.Options := [poUsePipes, poNoConsole];

   try
     Proc.Active := True;
     //ShowMessage('Recording started.');
   except
     on E: Exception do
     begin
       ShowMessage('Error starting FFmpeg: ' + E.Message);
     end;
   end;

   RecBtn.Enabled := False;
   PlayBtn.Enabled := False;
   FMinute := 0;
   FSecond := 0;
   Minute.Caption := '0';
   Second.Caption := '00';
   Timer.Enabled := True;
end;

function TScreenRec.generateFileName: string;
var
  i: integer;
  FOk: boolean;
  fname: string;
begin
  i:=1;
  FOk:=False;
  repeat
    fname:=Concat('/tmp/video_',IntToStr(i),'.mp4');
    if not FileExists(fname) then
      FOk:=True;
    Inc(i);
  until FOk;
  Result:=fname;
end;

procedure TScreenRec.FormCreate(Sender: TObject);
begin
  Proc.Options:=[poUsePipes, poNoConsole];
  VideoFile.Text:=generateFileName;
end;

procedure TScreenRec.KillBtnClick(Sender: TObject);
begin
  if Proc.Running then
    Proc.Active:=False
  else
    ShowMessage('Not Running.');
end;

procedure TScreenRec.PlayBtnClick(Sender: TObject);
begin
  if Proc.Active then
    Exit;

  Proc.Executable := '/usr/bin/mplayer';
  Proc.Parameters.Clear;
  Proc.Parameters.Add(VideoFile.Text);
  RecBtn.Enabled := False; // Disable start recording button during playback

  try
    Proc.Active := True; // Start playback
    Proc.WaitOnExit;     // Wait for playback process to finish
  finally
    RecBtn.Enabled := True; // Re-enable start recording button after playback
  end;
end;

procedure TScreenRec.RecBtnClick(Sender: TObject);
begin
  if FileExists(VideoFile.Text) then
    VideoFile.Text:=generateFileName;
  if (RecX.Text = '') or (RecY.Text = '') then
    begin
      ShowMessage('Error: Recording position (X, Y) is not set.');
      Exit;
    end;
  startRecording;
end;

procedure TScreenRec.StopBtnClick(Sender: TObject);
var
  QuitCommand: string;
  TimeoutMs: Integer;
  ProcessWasRunning: Boolean;
begin
  // Check if the process is running before sending commands
  ProcessWasRunning := Proc.Running;

  if ProcessWasRunning then
  begin
    // Attempt to gracefully stop FFmpeg
    QuitCommand := 'q';
    Proc.Input.Write(QuitCommand[1], Length(QuitCommand)); // Send 'q'
    Proc.CloseInput; // Signal EOF to FFmpeg

    // Wait for FFmpeg to exit gracefully
    TimeoutMs := 5000; // Wait up to 5 seconds
    if not Proc.WaitOnExit(TimeoutMs) then
    begin
      // If FFmpeg doesn't exit, force terminate the process
      Proc.Terminate(0); // Force termination
      Proc.WaitOnExit; // Ensure process has fully terminated
    end;
  end;

  // Stop the timer and read process output
  Timer.Enabled := False;

  // Show messages based on the process state
  if ProcessWasRunning then
  begin
    ShowMessage('Recording stopped.');
  end
  else
  begin
    ShowMessage('Process was not running.');
  end;

  // Ensure buttons are re-enabled
  RecBtn.Enabled := True;
  PlayBtn.Enabled := True;
end;

procedure TScreenRec.TimerTimer(Sender: TObject);
begin
  if Not Proc.Running then
  begin
    Timer.Enabled:=False;
    ShowMessage('Recording has stopped!');
    Exit;
  end;
  Inc(FSecond);
  if FSecond = 60 then
  begin
    Inc(FMinute);
    FSecond:=0;
  end;
  Minute.Caption:=IntToStr(FMinute);
  Second.Caption:=IntToStr(FSecond);
end;

procedure TScreenRec.CopyYBtnClick(Sender: TObject);
begin
  RecY.Text:=VBoxY.Text;
end;

end.

