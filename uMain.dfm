object xDelivererService: TxDelivererService
  OldCreateOrder = False
  DisplayName = 'xDelivererService'
  AfterInstall = ServiceAfterInstall
  AfterUninstall = ServiceAfterUninstall
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
