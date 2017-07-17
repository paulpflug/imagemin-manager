# imagemin-manager

declarative use of imagemin \o/.

Features:
  - image processing powered by [imagemin](https://github.com/imagemin/imagemin)
  - image preprocessing powered by [jimp](https://github.com/oliver-moran/jimp)
  - will skip files, when the source and the config file are older then the target

### Install

```sh
npm install --save-dev imagemin-manager
```

### Usage

```js
// imagemin.config.js
module.exports = { 
  from: ["resources"],
  to: "deploy/resources",
  process: {
    ico: "copy", // will match files with /.ico$/
    jpg: require("imagemin-guetzli")({quality: 87})
  }
  preprocess: {// see jimp for available commands
    jpg: [
      ["resize","AUTO",400]
    ]
  }
}
```
```sh
# call in terminal:
imagemin-manager
```
```js
// or use a task in your package.json
...
  "scripts": {
    ...
    "deploy:imagemin": "imagemin-manager"
    ...
  }
...
```
## License
Copyright (c) 2017 Paul Pflugradt
Licensed under the MIT license.
