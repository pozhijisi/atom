_ = require 'underscore-plus'
{ipcRenderer, remote, shell, webFrame} = require 'electron'
ipcHelpers = require './ipc-helpers'
{Disposable} = require 'event-kit'
{getWindowLoadSettings, setWindowLoadSettings} = require './window-load-settings-helpers'

module.exports =
class ApplicationDelegate
  open: (params) ->
    ipcRenderer.send('open', params)

  pickFolder: (callback) ->
    responseChannel = "atom-pick-folder-response"
    ipcRenderer.on responseChannel, (event, path) ->
      ipcRenderer.removeAllListeners(responseChannel)
      callback(path)
    ipcRenderer.send("pick-folder", responseChannel)

  getCurrentWindow: ->
    remote.getCurrentWindow()

  closeWindow: ->
    ipcRenderer.send("call-window-method", "close")

  getWindowSize: ->
    [width, height] = remote.getCurrentWindow().getSize()
    {width, height}

  setWindowSize: (width, height) ->
    ipcHelpers.call('set-window-size', width, height)

  getWindowPosition: ->
    [x, y] = remote.getCurrentWindow().getPosition()
    {x, y}

  setWindowPosition: (x, y) ->
    ipcHelpers.call('set-window-position', x, y)

  centerWindow: ->
    ipcHelpers.call('center-window')

  focusWindow: ->
    ipcHelpers.call('focus-window')

  showWindow: ->
    ipcHelpers.call('show-window')

  hideWindow: ->
    ipcHelpers.call('hide-window')

  reloadWindow: ->
    ipcRenderer.send("call-window-method", "reload")

  isWindowMaximized: ->
    remote.getCurrentWindow().isMaximized()

  maximizeWindow: ->
    ipcRenderer.send("call-window-method", "maximize")

  isWindowFullScreen: ->
    remote.getCurrentWindow().isFullScreen()

  setWindowFullScreen: (fullScreen=false) ->
    ipcRenderer.send("call-window-method", "setFullScreen", fullScreen)

  openWindowDevTools: ->
    new Promise (resolve) ->
      # Defer DevTools interaction to the next tick, because using them during
      # event handling causes some wrong input events to be triggered on
      # `TextEditorComponent` (Ref.: https://github.com/atom/atom/issues/9697).
      process.nextTick ->
        if remote.getCurrentWindow().isDevToolsOpened()
          resolve()
        else
          remote.getCurrentWindow().once("devtools-opened", -> resolve())
          ipcRenderer.send("call-window-method", "openDevTools")

  closeWindowDevTools: ->
    new Promise (resolve) ->
      # Defer DevTools interaction to the next tick, because using them during
      # event handling causes some wrong input events to be triggered on
      # `TextEditorComponent` (Ref.: https://github.com/atom/atom/issues/9697).
      process.nextTick ->
        unless remote.getCurrentWindow().isDevToolsOpened()
          resolve()
        else
          remote.getCurrentWindow().once("devtools-closed", -> resolve())
          ipcRenderer.send("call-window-method", "closeDevTools")

  toggleWindowDevTools: ->
    new Promise (resolve) =>
      # Defer DevTools interaction to the next tick, because using them during
      # event handling causes some wrong input events to be triggered on
      # `TextEditorComponent` (Ref.: https://github.com/atom/atom/issues/9697).
      process.nextTick =>
        if remote.getCurrentWindow().isDevToolsOpened()
          @closeWindowDevTools().then(resolve)
        else
          @openWindowDevTools().then(resolve)

  executeJavaScriptInWindowDevTools: (code) ->
    ipcRenderer.send("execute-javascript-in-dev-tools", code)

  setWindowDocumentEdited: (edited) ->
    ipcRenderer.send("call-window-method", "setDocumentEdited", edited)

  setRepresentedFilename: (filename) ->
    ipcRenderer.send("call-window-method", "setRepresentedFilename", filename)

  addRecentDocument: (filename) ->
    ipcRenderer.send("add-recent-document", filename)

  setRepresentedDirectoryPaths: (paths) ->
    loadSettings = getWindowLoadSettings()
    loadSettings['initialPaths'] = paths
    setWindowLoadSettings(loadSettings)

  setAutoHideWindowMenuBar: (autoHide) ->
    ipcRenderer.send("call-window-method", "setAutoHideMenuBar", autoHide)

  setWindowMenuBarVisibility: (visible) ->
    remote.getCurrentWindow().setMenuBarVisibility(visible)

  getPrimaryDisplayWorkAreaSize: ->
    remote.screen.getPrimaryDisplay().workAreaSize

  confirm: ({message, detailedMessage, buttons}) ->
    buttons ?= {}
    if _.isArray(buttons)
      buttonLabels = buttons
    else
      buttonLabels = Object.keys(buttons)

    chosen = remote.dialog.showMessageBox(remote.getCurrentWindow(), {
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttonLabels
    })

    if _.isArray(buttons)
      chosen
    else
      callback = buttons[buttonLabels[chosen]]
      callback?()

  showMessageDialog: (params) ->

  showSaveDialog: (params) ->
    if _.isString(params)
      params = defaultPath: params
    else
      params = _.clone(params)
    params.title ?= 'Save File'
    params.defaultPath ?= getWindowLoadSettings().initialPaths[0]
    remote.dialog.showSaveDialog remote.getCurrentWindow(), params

  playBeepSound: ->
    shell.beep()

  onDidOpenLocations: (callback) ->
    outerCallback = (event, message, detail) ->
      if message is 'open-locations'
        callback(detail)

    ipcRenderer.on('message', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('message', outerCallback)

  onUpdateAvailable: (callback) ->
    outerCallback = (event, message, detail) ->
      if message is 'update-available'
        callback(detail)

    ipcRenderer.on('message', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('message', outerCallback)

  onApplicationMenuCommand: (callback) ->
    outerCallback = (event, args...) ->
      callback(args...)

    ipcRenderer.on('command', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('command', outerCallback)

  onContextMenuCommand: (callback) ->
    outerCallback = (event, args...) ->
      callback(args...)

    ipcRenderer.on('context-command', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('context-command', outerCallback)

  didCancelWindowUnload: ->
    ipcRenderer.send('did-cancel-window-unload')

  openExternal: (url) ->
    shell.openExternal(url)

  disablePinchToZoom: ->
    webFrame.setZoomLevelLimits(1, 1)
