path = require "path"
fs = require "fs-extra"
imagemin = require "imagemin"

configTime = null

arrayize = (obj) => 
  if Array.isArray(obj)
    return obj
  else unless obj?
    return []
  else
    return [obj]

getFiles = (dirpath) =>
  files = await fs.readdir(dirpath)
  await Promise.all files.map (filename) =>
    fullpath = path.resolve(dirpath,filename)
    {mtimeMs} = await fs.stat fullpath
    return {path: fullpath, name: filename, mtime: mtimeMs}

findFilesToProcess = (fromFiles, toFiles, toDir) =>
  fromFiles.reduce ((found, current) =>
    existing = toFiles.find (toCompare) => toCompare.name == current.name
    if not existing or existing.mtime < Math.max(current.mtime, configTime)
      current.target = path.resolve(toDir, current.name)
      found.push current
    else
      console.log "skipping file: #{current.name}"
    return found
    ), []

furtherProcess = (regex, files) =>
  files.reduce ((found, current) =>
    found.push current if current.name.match regex
    return found), []

copyFiles = (files) => files.map (file) => fs.copy(file.path, file.target)

filesToPaths = (files) => files.map (file) => file.path

filesToNames = (files) => files.map (file) => file.name

module.exports = (config) =>
  unless config?
    files = await fs.readdir(process.cwd())
    for ext in ["js","coffee"]
      if ~files.indexOf(tmp = "imagemin.config.#{ext}")
        config = tmp
        break
  throw new Error "no imagemin.config found" unless config 
  if path.extname(config) == ".coffee"
    try
      require "coffeescript/register"
    catch
      try
        require "coffee-script/register"
  config = require (configPath = path.resolve(config))
  stats = await fs.stat configPath
  configTime = stats.mtimeMs
  toDir = path.resolve(config.to)
  await fs.ensureDir(toDir)
  toFiles = await getFiles toDir
  fromFiles = await Promise.all arrayize(config.from).map (dir) => getFiles path.resolve(dir)
    .then (filesArr) =>
      filesArr.reduce (current,arr) => current.concat(arr)
  files = findFilesToProcess(fromFiles, toFiles, toDir)
  
  types = {}
  workers = []
  jimp = null
  for ext, type of config.process
    tmpFiles = furtherProcess(new RegExp(".#{ext}$"), files)
    if tmpFiles.length > 0
      console.log "\nprocessing: #{filesToNames(tmpFiles)}"
      if (pre = config.preprocess[ext])?
        jimp ?= require("jimp")
        pre = pre.map (cmd) => cmd.map (prop) => if jimp[prop] then jimp[prop] else prop
        for file in tmpFiles
          chain = pre.reduce ((current, cmd) => 
            current.then ((cmd, img) => img[cmd.shift()].apply(img,cmd)).bind null, cmd
            return current
          ), jimp.read file.path
          chain = chain.then (img) => img.getBuffer jimp.AUTO, (err, buffer) ->
            throw err if err?
            return buffer
          if type != "copy"
            chain = chain.then ((type, buffer) => imagemin.buffer buffer, plugins: [type]).bind(null, type)
          workers.push chain.then fs.outputFile.bind(null, file.target)
      else
        if type == "copy"
          workers.push Promise.all copyFiles(tmpFiles)
        else
          workers.push imagemin(filesToPaths(tmpFiles), toDir, plugins: [type])

  Promise.all(workers).catch console.error
if process.argv[0] == "coffee"
  module.exports()