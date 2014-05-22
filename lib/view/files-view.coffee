{$, $$, SelectListView} = require 'atom'
LocalFile = require '../model/local-file'

fs = require 'fs'
os = require 'os'
async = require 'async'
util = require 'util'

module.exports =
  class FilesView extends SelectListView
    initialize: (@host) ->
      super
      @addClass('overlay from-top')

    connect: (@host) ->
      @path = @host.directory
      async.waterfall([
        (callback) =>
          @setLoading("Connecting...")
          @host.connect(callback)
        (callback) =>
          @populate(callback)
        ], (err, result) =>
          @setError(err) if err?
        )

    getFilterKey: ->
      return "name"

    attach: ->
      atom.workspaceView.append(this)
      @focusFilterEditor()

    cancel: ->
      @hide()

    viewForItem: (item) ->
      #console.debug 'viewforitem'
      $$ ->
        @li class: 'two-lines', =>
          if item.isFile
            @div class: 'primary-line icon icon-file-text', item.name
            @div class: 'secondary-line no-icon text-subtle', "Size: #{item.size}, Mtime: #{item.lastModified}, Permissions: #{item.permissions}"
          else if item.isDir
            @div class: 'primary-line icon icon-file-directory', item.name
            @div class: 'secondary-line no-icon text-subtle', "Size: #{item.size}, Mtime: #{item.lastModified}, Permissions: #{item.permissions}"
          else

    populate: (callback) ->
      async.waterfall([
        (callback) =>
          @setLoading("Loading...")
          @host.getFilesMetadata(@path, callback)
        (items, callback) =>
          @setItems(items)
          @cancelled()
        ], (err, result) =>
          @setError(err) if err?
          return callback(err, result)
        )

    getNewPath: (next) ->
      if (@path[@path.length - 1] == "/")
        @path + next
      else
        @path + "/" + next

    updatePath: (next) =>
      @path = @getNewPath(next)

    openFile: (file) =>
      savePath = os.tmpdir() + file.name
      async.waterfall([
        (callback) =>
          @host.getFileData(file, callback)
        (data, callback) =>
          fs.writeFile(savePath, data, (err) -> callback(err, savePath))
        ], (err, result) =>
          @setError(err) if err?
          localFile = new LocalFile(savePath, file)
          @host.localFiles.push(localFile)
          atom.workspace.open(localFile.path)
        )

    confirmed: (item) ->
      if item.isFile
        #console.debug 'file selected'
        @openFile(item)
      else if item.isDir
        @setItems()
        @updatePath(item.name)
        @populate()
      else
        @setError("Selected item is neither a file nor a directory!")
        #throw new Error("Path is neither a file nor a directory!")
