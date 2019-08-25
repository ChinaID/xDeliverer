unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.IniFiles, System.StrUtils, System.Win.Registry,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs,
  uMySFTPClient, IdFtp, IdAllFTPListParsers,
  ComCtrls, ExtCtrls, CheckLst;

type

  TWorkflowThread = class(TThread)
  protected
    procedure Execute; override;
  end;

  TProtocol = (SFTP, FTP);

  Tf = class
    fs: TFileStream;
    LocalPath, LocalFileName, RemotePath, RemoteFileName: String;
  end;

  Ts = class
    Host, Username, Password: String;
    Port: Word;
    Protocol: TProtocol;
  end;

  TxDelivererService = class(TService)
    procedure RecordLog(Log: AnsiString = '');
    procedure ServiceAfterInstall(Sender: TService);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceAfterUninstall(Sender: TService);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceShutdown(Sender: TService);
  private
    thread: TWorkflowThread;
    { Private declarations }
  public
    SFTPClient: TSFTPClient;
    FTPClient: TIdFTP;
    ConfigureFileName: String;
    ConfigureFile: TIniFile;
    function InitializeConfigureFile: TIniFile;
    function ExtractFileNameWithoutSuffix(FileString: String): String;
    function StrTrim(const input, finder: String): String;
    function ServerFileExists(Path, FileName: String): boolean;
    procedure StartTransfer;
    procedure byFTP();
    procedure bySFTP();
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  xDelivererService: TxDelivererService;
  f: Tf;
  s: Ts;

implementation

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  xDelivererService.Controller(CtrlCode);
end;

procedure TxDelivererService.RecordLog(Log: AnsiString);
var
  LogFile: TextFile;
  LogFileName: String;
begin
  LogFileName := ExtractFilePath(ParamStr(0))
  + ExtractFileNameWithoutSuffix(ParamStr(0)) + '.log';
  AssignFile(LogFile, LogFileName);

  if not FileExists(LogFileName) then Rewrite(LogFile);
  Append(LogFile);

  if Log <> '' then WriteLN(LogFile, DateTimeToStr(now()) + ': ' + Log)
  else WriteLN(LogFile, #13);

  CloseFile(LogFile);
end;

procedure TxDelivererService.ServiceAfterInstall(Sender: TService);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('\SYSTEM\CurrentControlSet\Services\' + Name, false) then
    begin
      Reg.WriteString('Description', 'This is a very simple ftp/sftp file automatic delivery service application.');
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TxDelivererService.ServiceAfterUninstall(Sender: TService);
var
  Reg: TRegistry;
  Key: string;
begin
  Key := '\SYSTEM\CurrentControlSet\Services\Eventlog\Application\' + Name;
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.KeyExists(Key) then
      Reg.DeleteKey(Key);
  finally
    Reg.Free;
  end;
end;

procedure TxDelivererService.ServiceShutdown(Sender: TService);
begin
  if Assigned(thread) then
  begin
    thread.Terminate;
    while WaitForSingleObject(thread.Handle, WaitHint-100) = WAIT_TIMEOUT do begin
      RecordLog(inttostr(WaitHint-100));
      ReportStatus;
    end;
    FreeAndNil(thread);
  end;
end;

procedure TxDelivererService.ServiceStart(Sender: TService; var Started: Boolean);
begin
  ConfigureFile := InitializeConfigureFile;
  RecordLog('Service initialization.');
  if not Assigned(thread) then begin
    try
      RecordLog('Create thread.');
      thread := TWorkflowThread.Create();
      try
        thread.Start;
      except
        ;
      end;
    except
      ;
    end;
  end;
  Started := true;
end;

procedure TxDelivererService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  ServiceShutdown(Sender);
  Stopped := True;
end;

procedure TxDelivererService.StartTransfer();
var
  Protocol: String;
begin
  RecordLog('Session initialization.');

  f := Tf.Create;
  s := Ts.Create;

  s.Host := ConfigureFile.ReadString('Server', 'host', '');
  if s.Host = '' then begin RecordLog('ERR: No host can be connected.'); exit; end
  else RecordLog('Server host: ' + s.Host);

  s.UserName := ConfigureFile.ReadString('Server', 'username', '');
  if s.UserName = '' then begin RecordLog('ERR: No username for authencation.'); exit; end
  else RecordLog('Server username: ' + s.Username);

  s.Password := ConfigureFile.ReadString('Server', 'password', '');
  if s.Password = '' then begin RecordLog('ERR: No password for authencation.'); exit; end
  else RecordLog('Server password: ' + s.Password);

  f.LocalPath := ConfigureFile.ReadString('Local', 'path', '');
  if f.LocalPath <> '' then f.LocalPath := StrTrim(StrTrim(f.LocalPath, '\'), '/') + '\'
  else f.LocalPath := ExtractFileDir(ParamStr(0)) + '\';

  f.LocalFileName := ConfigureFile.ReadString('Local', 'filename', '');
  if f.LocalFileName = '' then begin RecordLog('ERR: No file can be transfered.'); exit; end;

  f.RemotePath := StrTrim(StrTrim(ConfigureFile.ReadString('Server', 'path', ''), '\'), '/') + '/';

  f.RemoteFileName := ConfigureFile.ReadString('Server', 'filename', '');
  if f.RemoteFileName = '' then f.RemoteFileName := f.LocalFileName;

  Protocol := ConfigureFile.ReadString('Server', 'protocol', 'sftp');
  if Protocol = 'sftp' then s.Protocol := SFTP
  else if Protocol = 'ftp' then s.Protocol := FTP;

  s.Port := ConfigureFile.ReadInteger('Server', 'port', 0);
  if s.Port > 0 then s.Port := s.Port
  else begin
    if s.Protocol = FTP then s.Port := 21
    else if s.Protocol = SFTP then s.Port := 22;
  end;
  RecordLog('Server port: ' + IntToStr(s.Port));

  case s.Protocol of
    FTP: byFTP();
    SFTP: bySFTP();
  else begin RecordLog('ERR: Protocol can not recognize'); exit; end;
  end;

  RecordLog('Session completed.');
  RecordLog('');
end;

procedure TxDelivererService.bySFTP();
begin
  RecordLog('Protocol set to SFTP.');
  SFTPClient := TSFTPClient.Create(Self);
  SFTPClient.Host := s.Host;
  SFTPClient.UserName := s.Username;
  SFTPClient.Password := s.Password;
  SFTPClient.AuthModes :=  [amPassword];
  try
    RecordLog('Trying to connect to server.');
    SFTPClient.Connect;
    if not SFTPClient.Connected then begin
      RecordLog('ERR: ' + SFTPClient.GetLastSSHError);
      RecordLog('Connect to server failed, session terminated.');
      exit;
    end;
    RecordLog('Connected to server.');
    try
      f.fs := TFileStream.Create(f.LocalPath + f.LocalFileName, fmOpenRead or fmShareDenyWrite);
      RecordLog('Read file ' + f.LocalPath + f.LocalFileName + ' for transfer.');
      try
        RecordLog('Starting transfer.');
        SFTPClient.Put(f.fs, f.RemotePath + f.RemoteFileName, true);
        if ServerFileExists(f.RemotePath, f.RemoteFileName) then RecordLog('Transfer completed.')
        else RecordLog('ERR: Transfer finished with error, file can not be found on server.');
      except
        on e: ESSH2Exception do RecordLog('ERR: ' + e.Message);
      end;
    except 
      on e: EFOpenERROR do RecordLog('ERR: ' + e.Message);
    end;
  except 
    on e: ESSH2Exception do RecordLog('ERR:' + e.Message);
  end;
  RecordLog('Disconnect from server.');
  SFTPClient.Disconnect;
end;

procedure TxDelivererService.byFTP();
begin
  RecordLog('Protocol set to FTP.');
  FTPClient := TIdFTP.Create(Self);
  FTPClient.Host := s.Host;
  FTPClient.Username := s.Username;
  FTPClient.Password := s.Password;
  FTPClient.Port := s.Port;
  try
    RecordLog('Trying to connect to server.');
    FTPClient.Connect;
    if not FTPClient.Connected then begin
      RecordLog('ERR: ' + FTPClient.LastCmdResult.Text.Text);
      RecordLog('Connect to server failed, session terminated.');
      exit;
    end;
    RecordLog('Connected to server.');
    if FTPClient.RetrieveCurrentDir <> f.RemotePath then FTPClient.ChangeDir(f.RemotePath);
    f.fs := TFileStream.Create(f.LocalPath + f.LocalFileName, fmOpenRead or fmShareDenyWrite);
    RecordLog('Read file ' + f.LocalPath + f.LocalFileName + ' for transfer.');
    try
      RecordLog('Starting transfer.');
      FTPClient.Passive := true;
      FTPClient.Put(f.fs, f.RemoteFileName);
      if ServerFileExists(f.RemotePath, f.RemoteFileName) then RecordLog(f.RemotePath + f.RemoteFileName + ' has been stored on server, transfer completed.')
      else RecordLog('ERR: Transfer finished with error, file can not be found on server.');
    except
      on e: Exception do RecordLog('ERR:' + e.Message);
    end;
  except
    on e: Exception do RecordLog('ERR:' + e.Message);
  end;
  RecordLog('Disconnect from server.');
  FTPClient.Disconnect;
end;

function TxDelivererService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

function TxDelivererService.ServerFileExists(Path, FileName: String): boolean;
var
  i: Integer;
begin
  if s.Protocol = SFTP then begin
    if SFTPClient.CurrentDirectory <> Path then SFTPClient.CurrentDirectory := Path;
    SFTPClient.List;
    for i := 0 to SFTPClient.DirectoryItems.Count - 1 do
      if SFTPClient.DirectoryItems[i].FileName = FileName then exit(true);
  end else begin
    if FTPClient.RetrieveCurrentDir <> f.RemotePath then FTPClient.ChangeDir(f.RemotePath);
    FTPClient.List('', true);
    for i := 0 to FTPClient.DirectoryListing.Count -1 do
      if FTPClient.DirectoryListing[i].FileName = FileName then exit(true);
  end;
  exit(false);
end;

function TxDelivererService.StrTrim(const input, finder: String): String;
begin
  if String(RightStr(input, 1)) = finder then Result := String(LeftStr(input, input.Length - 1))
  else Result := input;
end;

function TxDelivererService.ExtractFileNameWithoutSuffix(FileString: String): String;
var
  FileWithExtString: String;
  FileExtString: String;
  LenExt: Integer;
  LenNameWithExt: Integer;
begin
  FileWithExtString := ExtractFileName(FileString);
  LenNameWithExt    := Length(FileWithExtString);
  FileExtString     := ExtractFileExt(FileString);
  LenExt            := Length(FileExtString);
  if LenExt = 0 then Result := FileWithExtString
  else Result := Copy(FileWithExtString, 1, (LenNameWithExt - LenExt));
end;

function TxDelivererService.InitializeConfigureFile: TIniFile;
var
  IniFile: TextFile;
begin
  ConfigureFileName := ExtractFilePath(ParamStr(0))
  + ExtractFileNameWithoutSuffix(ParamStr(0)) + '.ini';
  if not FileExists(ConfigureFileName) then begin
    RecordLog('Configuration file ' + ConfigureFileName + ' does not exist.');
    RecordLog('Trying to create configuration file.');
    AssignFile(IniFile, ConfigureFileName);
    Rewrite(IniFile);
    if not FileExists(ConfigureFileName) then begin
      RecordLog('Create configuration failed, service terminated.');
      exit;
    end else begin
      RecordLog('Created configuration file without parameters.');
      Append(IniFile);
      WriteLN(IniFile, '[Server]');
      WriteLN(IniFile, 'host=');
      WriteLN(IniFile, 'username=');
      WriteLN(IniFile, 'password=');
      WriteLN(IniFile, 'port=');
      WriteLN(IniFile, 'protocol=sftp');
      WriteLN(IniFile, 'path=');
      WriteLN(IniFile, 'filename=');
      WriteLN(IniFile, '[Local]');
      WriteLN(IniFile, 'path=');
      WriteLN(IniFile, 'filename=');
      WriteLN(IniFile, '[Schedule]');
      WriteLN(IniFile, 'when=');
      CloseFile(IniFile);
      RecordLog('Please restart services to apply new settings after configuration file has been full filled or modified.');
    end;
  end;
  Result := TIniFile.Create(ConfigureFileName);
end;

{ TWorkflowThread }

procedure TWorkflowThread.Execute;
var
  t: String;
begin
  inherited;
  if xDelivererService.ConfigureFile.ReadString('Schedule', 'when', '') <> '' then
  else xDelivererService.RecordLog('No schedule for session to start.');
  t := formatdatetime('hh:MM:ss', strtotime(xDelivererService.ConfigureFile.ReadString('Schedule', 'when', '')));
    while not Terminated do begin
      if formatdatetime('hh:MM:ss', strtotime(xDelivererService.ConfigureFile.ReadString('Schedule', 'when', ''))) <> t then begin
        t := formatdatetime('hh:MM:ss', strtotime(xDelivererService.ConfigureFile.ReadString('Schedule', 'when', '')));
        xDelivererService.RecordLog('Next session will be started at ' + t);
      end;
      if t = formatdatetime('hh:MM:ss', now()) then xDelivererService.StartTransfer();
      TThread.Sleep(1000);
    end;
end;

end.
