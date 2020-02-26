/**
 * 世嘉网页的爬虫
 * 网页地址 http://miku.sega.jp/arcade/item_module_rin.html
 * 图片地址参考 http://miku.sega.jp/arcade/img/item/module/etc_06.jpg
 */
const Axios = require("axios");
const fs = require("fs");
const path = require("path");
const { role, start = 0, end = 10, outputDir, ROLE } = require("./config");
const BASIC_PIC_PATH = "http://miku.sega.jp/arcade/img/item/module";

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
const downloadPic = async function(url, filepath, name) {
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

/**
 * 下载单个角色的
 * @param {*} _role
 * @param {*} _start
 * @param {*} _end
 */
const downloadRole = async function(_role, _start, _end) {
  const files = [...new Array(_end - _start + 1).keys()].map(index => {
    const fileName = `${_role}_${(index + _start + "").padStart(2, "0")}`;
    return {
      url: `${BASIC_PIC_PATH}/${fileName}.jpg`,
      fileName
    };
  });

  for (let file of files) {
    const { url, fileName } = file;

    // 下载
    try {
      await downloadPic(
        url,
        path.join(outputDir, _role, fileName),
        `index.jpg`
      );
      console.log("下载成功！", fileName);
    } catch (e) {
      console.error("下载失败", e);
      break;
    }
  }
};

(async function() {
  const roles = role ? [role] : Object.values(ROLE);
  roles.forEach(async _role => {
    await downloadRole(_role, start, end);
  });
})();
