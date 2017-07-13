path = require "path"
fs = require "fs-extra"
imagemin = require "imagemin"
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
    if not existing or existing.mtime < current.mtime
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
  config = require path.resolve(config)
  toDir = path.resolve(config.to)
  await fs.ensureDir(toDir)
  toFiles = await getFiles toDir
  fromFiles = await Promise.all arrayize(config.from).map (dir) => getFiles path.resolve(dir)
    .then (filesArr) =>
      filesArr.reduce (current,arr) => current.concat(arr)
  files = findFilesToProcess(fromFiles, toFiles, toDir)
  types = {}
  workers = []
  for ext, type of config.process
    tmpFiles = furtherProcess(new RegExp(".#{ext}$"), files)
    if tmpFiles.length > 0
      console.log "\nprocessing: #{filesToNames(tmpFiles)}"
      if type == "copy"
        workers.push Promise.all copyFiles(tmpFiles)
      else
        workers.push imagemin(filesToPaths(tmpFiles), toDir, plugins: [type])

  Promise.all(workers).catch console.error
if process.argv[0] == "coffee"
  module.exports()