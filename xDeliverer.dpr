program xDeliverer;

{$IF CompilerVersion >= 21.0}
{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$IFEND}

uses
  Vcl.SvcMgr,
  uMain in 'uMain.pas' {xDelivererService: TService},
  uMySFTPClient in 'uMySFTPClient.pas',
  HVDll in 'HVDll.pas',
  HVHeaps in 'HVHeaps.pas',
  libssh2 in 'libssh2.pas',
  libssh2_sftp in 'libssh2_sftp.pas',
  uFxtDelayedHandler in 'uFxtDelayedHandler.pas';

{$R *.RES}

begin
  // Windows 2003 Server requires StartServiceCtrlDispatcher to be
  // called before CoRegisterClassObject, which can be called indirectly
  // by Application.Initialize. TServiceApplication.DelayInitialize allows
  // Application.Initialize to be called from TService.Main (after
  // StartServiceCtrlDispatcher has been called).
  //
  // Delayed initialization of the Application object may affect
  // events which then occur prior to initialization, such as
  // TService.OnCreate. It is only recommended if the ServiceApplication
  // registers a class object with OLE and is intended for use with
  // Windows 2003 Server.
  //
  // Application.DelayInitialize := True;
  //
  if not Application.DelayInitialize or Application.Installing then
    Application.Initialize;
  Application.CreateForm(TxDelivererService, xDelivererService);
  Application.Run;
end.
