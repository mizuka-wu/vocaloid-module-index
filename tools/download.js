const Axios = require("axios");
const fs = require("fs");
const path = require("path");
/**
 *
 * @param {*} url
 */
function deleteFolderSync(url) {
  var files = [];
  /**
   * 判断给定的路径是否存在
   */
  if (fs.existsSync(url)) {
    /**
     * 返回文件和子目录的数组
     */
    files = fs.readdirSync(url);
    files.forEach(function(file, index) {
      var curPath = path.join(url, file);
      /**
       * fs.statSync同步读取文件夹文件，如果是文件夹，在重复触发函数
       */
      if (fs.statSync(curPath).isDirectory()) {
        // recurse
        deleteFolderRecursive(curPath);
      } else {
        fs.unlinkSync(curPath);
      }
    });
    /**
     * 清除文件夹
     */
    fs.rmdirSync(url);
  } else {
    console.log("给定的路径不存在，请给出正确的路径");
  }
}

/**
 * 下载图片
 * @param {*} url
 * @param {*} filepath
 * @param {*} name
 */
const downloadPic = async function(url, filepath, name, moduleFrom) {
  if (!fs.existsSync(filepath)) {
    fs.mkdirSync(filepath);
  }
  const outputpath = path.resolve(filepath, name);
  const writer = fs.createWriteStream(outputpath);
  const response = await Axios({
    url,
    method: "GET",
    responseType: "stream"
  });
  response.data.pipe(writer);
  return new Promise((resolve, reject) => {
    writer.on("finish", () => {
      fs.writeFileSync(
        path.resolve(filepath, "README.md"),
        `
  # 模组信息

  ![](./${name})

  ## 模组名称
  ${
    moduleFrom
      ? `- **${moduleFrom}** ${
          outputpath.split("/")[outputpath.split("/").length - 2]
        }`
      : ""
  }
  `
      );
      resolve();
    });
    writer.on("error", function(e) {
      deleteFolderSync(filepath);
      reject(e);
    });
  });
};

module.exports = downloadPic;
