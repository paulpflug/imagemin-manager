module.exports =
  from: "test/from"
  to: "test/to"
  process:
    txt: "copy"
    jpg: require("imagemin-guetzli")({quality: 87})