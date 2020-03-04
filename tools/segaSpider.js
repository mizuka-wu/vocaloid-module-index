/**
 * 世嘉网页的爬虫
 * 网页地址 http://miku.sega.jp/arcade/item_module_rin.html
 * 图片地址参考 http://miku.sega.jp/arcade/img/item/module/etc_06.jpg
 */
const path = require("path");
const { role, start = 0, end = 10, outputDir, ROLE } = require("./config");
const downloadPic = require("./download");
const BASIC_PIC_PATH = "http://miku.sega.jp/arcade/img/item/module";

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
